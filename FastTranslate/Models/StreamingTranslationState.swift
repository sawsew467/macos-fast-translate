import Foundation

/// Observable state driving the streaming floating panel.
/// Created before the stream starts so the panel can show immediately with loading state.
/// All mutations happen on the main thread (via @MainActor Task blocks in HotkeyManager).
final class StreamingTranslationState: ObservableObject {
    @Published var streamedText = ""
    @Published var isStreaming = true
    @Published var error: String?

    let sourceText: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let provider: ProviderType

    init(
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        provider: ProviderType
    ) {
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
    }

    /// Build a TranslationResult after streaming completes.
    var completedResult: TranslationResult {
        TranslationResult(
            sourceText: sourceText,
            translatedText: streamedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            provider: provider
        )
    }
}
