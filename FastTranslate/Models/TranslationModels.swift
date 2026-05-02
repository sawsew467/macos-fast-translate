import Foundation

// MARK: - Language

enum Language: String, CaseIterable, Codable {
    case vietnamese = "vi"
    case english = "en"

    var displayName: String {
        switch self {
        case .vietnamese: return "Vietnamese"
        case .english: return "English"
        }
    }

    /// Returns the opposite language for Vi↔En toggle
    var toggled: Language {
        switch self {
        case .vietnamese: return .english
        case .english: return .vietnamese
        }
    }
}

// MARK: - Provider

enum ProviderType: String, CaseIterable, Codable {
    case openAI = "openai"

    var displayName: String {
        switch self {
        case .openAI: return "GPT-4o mini"
        }
    }
}

// MARK: - Translation context

struct TranslationContext {
    var persistent: String?   // From Settings, always included
    var perMessage: String?   // User-typed context for this translation
    var screenshot: String?   // OCR text from surrounding area (Phase 5)
}

// MARK: - Translation error

enum TranslationError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case rateLimited
    case invalidResponse
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key is not set. Please add your key in Settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limit reached. Please wait a moment and try again."
        case .invalidResponse:
            return "Invalid response from translation service."
        case .emptyInput:
            return "Please enter text to translate."
        }
    }
}

// MARK: - Translation result

struct TranslationResult: Codable {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let provider: ProviderType
    let timestamp: Date

    init(
        sourceText: String,
        translatedText: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        provider: ProviderType,
        timestamp: Date = .now
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.timestamp = timestamp
    }
}
