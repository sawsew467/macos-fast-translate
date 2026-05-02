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
}
