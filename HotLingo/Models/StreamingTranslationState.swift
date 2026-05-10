import Foundation

/// Observable state driving the streaming floating panel.
/// Created before the stream starts so the panel can show immediately with loading state.
/// All mutations happen on the main thread (via @MainActor Task blocks in HotkeyManager).
final class StreamingTranslationState: ObservableObject {
    @Published var streamedText = ""
    @Published var isStreaming = true
    @Published var error: String?
    @Published var targetLanguage: Language

    let sourceText: String
    let sourceLanguage: Language
    let provider: ProviderType
    let presentation: TranslationPresentation

    /// The active stream-consumer task. Cancel this before starting a new stream
    /// to prevent two Tasks racing to append to `streamedText`.
    var consumeTask: Task<Void, Never>?

    init(
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        provider: ProviderType,
        presentation: TranslationPresentation = .plain
    ) {
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.presentation = presentation
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

enum TranslationPresentation {
    case plain
    case conversation
}
