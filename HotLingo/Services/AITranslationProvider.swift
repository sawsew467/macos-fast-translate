import Foundation

/// AI translation via Supabase Edge Function.
/// Uses JWT auth, deducts 1 credit per translation, updates CreditService balance.
final class AITranslationProvider: TranslationProvider {
    let name = "AI Translation"
    let providerType: ProviderType = .aiTranslation

    func translate(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }
        guard await SupabaseClient.shared.isLoggedIn else {
            throw TranslationError.notAuthenticated
        }

        let body = TranslateRequestBody(
            text: text,
            target_lang: target.rawValue,
            context: buildContextString(context)
        )

        do {
            let response: TranslateResponse = try await SupabaseClient.shared.request(
                endpoint: "/functions/v1/translate",
                method: "POST",
                body: body
            )
            await MainActor.run {
                CreditService.shared.updateBalance(response.remaining_credits)
            }
            return response.translated_text
        } catch let error as SupabaseError {
            // Match both httpError(402) and serverError("[402] ...") since SupabaseError.parse
            // returns serverError when the response body contains a message.
            switch error {
            case .httpError(402):
                throw TranslationError.noCredits
            case .serverError(let msg) where msg.hasPrefix("[402]"):
                throw TranslationError.noCredits
            case .httpError(401), .notAuthenticated:
                throw TranslationError.notAuthenticated
            case .serverError(let msg) where msg.hasPrefix("[401]"):
                throw TranslationError.notAuthenticated
            default:
                throw TranslationError.networkError(error)
            }
        } catch {
            throw TranslationError.networkError(error)
        }
    }

    func translateStream(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) -> AsyncThrowingStream<String, Error> {
        let body = TranslateRequestBody(
            text: text,
            target_lang: target.rawValue,
            context: buildContextString(context)
        )

        return AsyncThrowingStream { continuation in
            Task {
                guard await SupabaseClient.shared.isLoggedIn else {
                    continuation.finish(throwing: TranslationError.notAuthenticated)
                    return
                }

                let sseStream = await SupabaseClient.shared.streamSSE(
                    endpoint: "/functions/v1/translate-stream",
                    body: body
                )

                do {
                    for try await payload in sseStream {

                        guard let data = payload.data(using: .utf8) else { continue }

                        // Metadata event: remaining_credits
                        if let meta = try? JSONDecoder().decode(CreditsPayload.self, from: data),
                           let credits = meta.remaining_credits {
                            await MainActor.run { CreditService.shared.updateBalance(credits) }
                            continue
                        }

                        // Content delta from OpenRouter SSE chunk
                        if let chunk = try? JSONDecoder().decode(OpenRouterChunk.self, from: data),
                           let delta = chunk.choices?.first?.delta?.content,
                           !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch let error as SupabaseError {
                    switch error {
                    case .httpError(402): continuation.finish(throwing: TranslationError.noCredits)
                    case .serverError(let msg) where msg.hasPrefix("[402]"): continuation.finish(throwing: TranslationError.noCredits)
                    case .httpError(401), .notAuthenticated: continuation.finish(throwing: TranslationError.notAuthenticated)
                    case .serverError(let msg) where msg.hasPrefix("[401]"): continuation.finish(throwing: TranslationError.notAuthenticated)
                    default: continuation.finish(throwing: TranslationError.networkError(error))
                    }
                } catch {
                    continuation.finish(throwing: TranslationError.networkError(error))
                }
            }
        }
    }

    // MARK: - Private

    private func buildContextString(_ context: TranslationContext?) -> String? {
        guard let context else { return nil }
        let parts = [context.persistent, context.perMessage, context.screenshot]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}

private struct TranslateRequestBody: Encodable {
    let text: String
    let target_lang: String
    let context: String?
}

// MARK: - SSE Payload Types

private struct CreditsPayload: Decodable {
    let remaining_credits: Int?
}

private struct OpenRouterChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta?
    }
    let choices: [Choice]?
}
