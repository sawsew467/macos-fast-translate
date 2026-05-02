import Foundation
import Combine

/// Coordinator for translation: detects language, merges 3 context layers, calls active provider.
/// Publishes state for SwiftUI binding. History capped at 50 entries.
@MainActor
final class TranslationService: ObservableObject {
    @Published var isTranslating = false
    @Published private(set) var lastResult: TranslationResult?
    @Published private(set) var history: [TranslationResult] = []

    private let providers: [ProviderType: any TranslationProvider]
    private let maxHistoryCount = 50

    /// Persistent context set by user in Settings (Phase 7)
    var persistentContext: String {
        UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.persistentContext) ?? ""
    }

    var activeProviderType: ProviderType {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.defaultProvider) ?? ""
        return ProviderType(rawValue: raw) ?? .openAI
    }

    init() {
        providers = [.openAI: OpenAITranslationProvider()]
        loadHistory()
    }

    /// Translate text with optional per-message and screenshot context layers.
    func translate(
        _ text: String,
        perMessageContext: String? = nil,
        screenshotContext: String? = nil
    ) async throws -> TranslationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }

        isTranslating = true
        defer { isTranslating = false }

        let source = LanguageDetector.detect(text)
        let target = source.toggled

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

        lastResult = result
        history.insert(result, at: 0)
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        saveHistory()
        return result
    }

    // MARK: - History persistence

    private func historyFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("FastTranslate/history.json")
    }

    private func loadHistory() {
        guard let url = historyFileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([TranslationResult].self, from: data)
        else { return }
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
