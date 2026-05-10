import Foundation

/// GPT-4o-mini translation via OpenAI Chat Completions API.
/// API key is read from UserDefaults (UI for entry handled in Phase 7).
final class OpenAITranslationProvider: TranslationProvider {
    let name = "GPT-4o mini"
    let providerType: ProviderType = .openAI

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func translate(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }

        let apiKey = KeychainHelper.load(account: Constants.KeychainAccount.openAIAPIKey) ?? ""
        guard !apiKey.isEmpty else { throw TranslationError.noAPIKey }

        let body = ChatRequest(
            model: "gpt-4o-mini",
            messages: [
                ChatMessage(role: "system", content: systemPrompt(source: source, to: target, context: context)),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.3,
            maxTokens: 2048
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw TranslationError.invalidResponse }

        switch http.statusCode {
        case 200: break
        case 401: throw TranslationError.noAPIKey
        case 429: throw TranslationError.rateLimited
        default:  throw TranslationError.invalidResponse
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw TranslationError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Streaming

    func translateStream(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildStreamRequest(text, from: source, to: target, context: context)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: TranslationError.invalidResponse)
                        return
                    }
                    switch http.statusCode {
                    case 200: break
                    case 401: continuation.finish(throwing: TranslationError.noAPIKey); return
                    case 429: continuation.finish(throwing: TranslationError.rateLimited); return
                    default:  continuation.finish(throwing: TranslationError.invalidResponse); return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(ChatStreamChunk.self, from: data),
                              let content = chunk.choices.first?.delta.content
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch let error as TranslationError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: TranslationError.networkError(error))
                }
            }
        }
    }

    private func buildStreamRequest(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) throws -> URLRequest {
        let apiKey = KeychainHelper.load(account: Constants.KeychainAccount.openAIAPIKey) ?? ""
        guard !apiKey.isEmpty else { throw TranslationError.noAPIKey }

        let body = ChatStreamRequest(
            model: "gpt-4o-mini",
            messages: [
                ChatMessage(role: "system", content: systemPrompt(source: source, to: target, context: context)),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.3,
            maxTokens: 2048,
            stream: true
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Prompt builder

    private func systemPrompt(source: Language, to target: Language, context: TranslationContext?) -> String {
        let sourceInstruction = source == .autoDetect
            ? "Automatically detect the source language"
            : "The source language is \(source.displayName)"

        var prompt = """
        You are a professional translator for any language.
        \(sourceInstruction) and translate the user's text to \(target.displayName).
        Return ONLY the translated text. Do not add explanations, language labels, or notes.
        Preserve the original meaning, formatting, tone, register, names, URLs, and code-like text.
        """

        let parts = [context?.persistent, context?.perMessage, context?.screenshot.map { "Surrounding text: \($0)" }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        if !parts.isEmpty {
            prompt += "\n\nAdditional context for accurate translation:\n" + parts.joined(separator: "\n")
        }
        return prompt
    }
}

// MARK: - Private codable models

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable { let message: ChatMessage }
    let choices: [Choice]
}

private struct ChatStreamRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

private struct ChatStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
