import Foundation
import Combine

/// Coordinator for translation: detects language, merges 3 context layers, calls active provider.
/// Publishes state for SwiftUI binding. History is persisted locally.
@MainActor
final class TranslationService: ObservableObject {
    @Published var isTranslating = false
    @Published private(set) var lastResult: TranslationResult?
    @Published private(set) var history: [TranslationResult] = []

    private let providers: [ProviderType: any TranslationProvider]
    /// Persistent context set by user in Settings (Phase 7)
    var persistentContext: String {
        UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.persistentContext) ?? ""
    }

    var activeProviderType: ProviderType {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.defaultProvider) ?? ""
        return ProviderType(rawValue: raw) ?? .googleTranslate
    }

    var defaultTargetLanguage: Language {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.defaultTargetLanguage) ?? ""
        let language = Language(rawValue: raw) ?? .vietnamese
        return language == .autoDetect ? .vietnamese : language
    }

    init() {
        providers = [
            .googleTranslate: GoogleTranslateProvider(),
            .openAI: OpenAITranslationProvider(),
            .aiTranslation: AITranslationProvider()
        ]
        loadHistory()
    }

    /// Translate text with optional per-message and screenshot context layers.
    func translate(
        _ text: String,
        targetLanguage: Language? = nil,
        perMessageContext: String? = nil,
        screenshotContext: String? = nil
    ) async throws -> TranslationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }

        isTranslating = true
        defer { isTranslating = false }

        let source = LanguageDetector.detect(text)
        let requestedTarget = targetLanguage ?? defaultTargetLanguage
        let target = source == requestedTarget ? requestedTarget.fallbackTarget : requestedTarget

        let persistent = persistentContext.isEmpty ? nil : persistentContext
        let context = TranslationContext(
            persistent: persistent,
            perMessage: perMessageContext,
            screenshot: screenshotContext
        )

        guard let provider = providers[activeProviderType] else {
            throw TranslationError.invalidResponse
        }

        let translated = try await provider.translate(text, from: source, to: target, context: context)

        let result = TranslationResult(
            sourceText: text,
            translatedText: translated,
            sourceLanguage: source,
            targetLanguage: target,
            provider: activeProviderType
        )

        loadHistory()
        lastResult = result
        history.insert(result, at: 0)
        saveHistory()
        return result
    }

    /// Start a streaming translation. Returns language info + token stream.
    /// Caller is responsible for consuming the stream and calling addToHistory() after.
    func translateStreaming(
        _ text: String,
        targetLanguage: Language? = nil,
        perMessageContext: String? = nil,
        screenshotContext: String? = nil
    ) throws -> (source: Language, target: Language, stream: AsyncThrowingStream<String, Error>) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }

        let source = LanguageDetector.detect(text)
        let requestedTarget = targetLanguage ?? defaultTargetLanguage
        let target = source == requestedTarget ? requestedTarget.fallbackTarget : requestedTarget

        let persistent = persistentContext.isEmpty ? nil : persistentContext
        let context = TranslationContext(
            persistent: persistent,
            perMessage: perMessageContext,
            screenshot: screenshotContext
        )

        guard let provider = providers[activeProviderType] else {
            throw TranslationError.invalidResponse
        }

        let stream = provider.translateStream(text, from: source, to: target, context: context)
        return (source, target, stream)
    }

    /// Save a completed translation to history. Called by hotkey handlers after streaming finishes.
    func addToHistory(_ result: TranslationResult) {
        loadHistory()
        lastResult = result
        history.insert(result, at: 0)
        saveHistory()
    }

    // MARK: - History persistence

    private func historyFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("HotLingo/history.json")
    }

    private func loadHistory() {
        guard let url = historyFileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([TranslationResult].self, from: data)
        else {
            history = []
            return
        }
        history = loaded
    }

    private func saveHistory() {
        guard let url = historyFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
