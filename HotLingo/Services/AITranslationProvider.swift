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

    // translateStream provided by protocol default (single-shot fallback)

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
