import Foundation

/// Protocol all translation providers must conform to.
protocol TranslationProvider {
    var name: String { get }
    var providerType: ProviderType { get }

    /// Translate text with optional 3-layer context for accuracy
    func translate(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) async throws -> String

    /// Stream translation tokens via SSE. Each element is a delta chunk.
    func translateStream(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Default streaming via single-shot fallback

extension TranslationProvider {
    func translateStream(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await translate(text, from: source, to: target, context: context)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
