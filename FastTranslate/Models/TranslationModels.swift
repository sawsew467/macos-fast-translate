import Foundation

// MARK: - Language

enum Language: String, CaseIterable, Codable, Identifiable {
    case autoDetect = "auto"
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    case thai = "th"
    case indonesian = "id"

    var id: String { rawValue }

    static var targetOptions: [Language] { allCases.filter { $0 != .autoDetect } }

    var displayName: String {
        switch self {
        case .autoDetect: return "Auto Detect"
        case .vietnamese: return "Vietnamese"
        case .english: return "English"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .simplifiedChinese: return "Chinese (Simplified)"
        case .traditionalChinese: return "Chinese (Traditional)"
        case .french: return "French"
        case .german: return "German"
        case .spanish: return "Spanish"
        case .portuguese: return "Portuguese"
        case .italian: return "Italian"
        case .russian: return "Russian"
        case .thai: return "Thai"
        case .indonesian: return "Indonesian"
        }
    }

    var shortName: String {
        switch self {
        case .autoDetect: return "Auto"
        case .vietnamese: return "VN"
        case .english: return "EN"
        case .japanese: return "JP"
        case .korean: return "KR"
        case .simplifiedChinese: return "CN"
        case .traditionalChinese: return "TW"
        case .french: return "FR"
        case .german: return "DE"
        case .spanish: return "ES"
        case .portuguese: return "PT"
        case .italian: return "IT"
        case .russian: return "RU"
        case .thai: return "TH"
        case .indonesian: return "ID"
        }
    }

    /// Legacy Vi-En fallback used when source already matches the target language.
    var fallbackTarget: Language {
        self == .english ? .vietnamese : .english
    }
}

// MARK: - Provider

enum ProviderType: String, CaseIterable, Codable {
    case googleTranslate = "google_translate"
    case openAI = "openai"

    var displayName: String {
        switch self {
        case .googleTranslate: return "Google Translate"
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
