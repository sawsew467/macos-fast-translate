import Foundation
import SwiftUI

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

    /// Use in non-SwiftUI contexts (e.g., accessibility labels, log messages).
    /// In SwiftUI views, prefer `localizationKey` so the environment locale is respected.
    var displayName: String {
        switch self {
        case .autoDetect: return String(localized: "language.autoDetect")
        case .vietnamese: return String(localized: "language.vietnamese")
        case .english: return String(localized: "language.english")
        case .japanese: return String(localized: "language.japanese")
        case .korean: return String(localized: "language.korean")
        case .simplifiedChinese: return String(localized: "language.simplifiedChinese")
        case .traditionalChinese: return String(localized: "language.traditionalChinese")
        case .french: return String(localized: "language.french")
        case .german: return String(localized: "language.german")
        case .spanish: return String(localized: "language.spanish")
        case .portuguese: return String(localized: "language.portuguese")
        case .italian: return String(localized: "language.italian")
        case .russian: return String(localized: "language.russian")
        case .thai: return String(localized: "language.thai")
        case .indonesian: return String(localized: "language.indonesian")
        }
    }

    /// Use in SwiftUI `Text(language.localizationKey)` so the view's environment locale is respected.
    var localizationKey: LocalizedStringKey {
        switch self {
        case .autoDetect: return "language.autoDetect"
        case .vietnamese: return "language.vietnamese"
        case .english: return "language.english"
        case .japanese: return "language.japanese"
        case .korean: return "language.korean"
        case .simplifiedChinese: return "language.simplifiedChinese"
        case .traditionalChinese: return "language.traditionalChinese"
        case .french: return "language.french"
        case .german: return "language.german"
        case .spanish: return "language.spanish"
        case .portuguese: return "language.portuguese"
        case .italian: return "language.italian"
        case .russian: return "language.russian"
        case .thai: return "language.thai"
        case .indonesian: return "language.indonesian"
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
    case aiTranslation = "ai_translation"

    var displayName: String {
        switch self {
        case .googleTranslate: return "Google Translate"
        case .openAI: return "GPT-4o mini"
        case .aiTranslation: return "AI Translation"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProviderType(rawValue: raw) ?? .googleTranslate
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
    case noCredits
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return String(localized: "error.noAPIKey")
        case .networkError(let error):
            return String(localized: "error.networkError \(error.localizedDescription)")
        case .rateLimited:
            return String(localized: "error.rateLimited")
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .emptyInput:
            return String(localized: "error.emptyInput")
        case .noCredits:
            return String(localized: "error.noCredits")
        case .notAuthenticated:
            return String(localized: "error.notAuthenticated")
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
