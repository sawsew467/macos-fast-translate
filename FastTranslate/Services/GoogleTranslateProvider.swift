import Foundation

/// Free Google Translate provider using the unofficial `translate.googleapis.com` endpoint.
/// No API key required. Does not support context or streaming (uses single-shot fallback).
final class GoogleTranslateProvider: TranslationProvider {
    let name = "Google Translate"
    let providerType: ProviderType = .googleTranslate

    func translate(
        _ text: String,
        from source: Language,
        to target: Language,
        context: TranslationContext?
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }

        let url = try buildURL(text: text, source: source, target: target)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        } catch {
            throw TranslationError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        switch http.statusCode {
        case 200: break
        case 429: throw TranslationError.rateLimited
        default:  throw TranslationError.invalidResponse
        }

        return try parseResponse(data: data)
    }

    // MARK: - Private helpers

    private func buildURL(text: String, source: Language, target: Language) throws -> URL {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: languageCode(for: source)),
            URLQueryItem(name: "tl", value: languageCode(for: target)),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = components.url else {
            throw TranslationError.invalidResponse
        }
        return url
    }

    /// Parse the nested JSON array response.
    /// Format: `[[["translated segment","source segment",...], ...], null, "detected_lang"]`
    /// Long texts are split across multiple inner arrays — join all translated segments.
    private func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let root = json as? [Any],
              let segments = root.first as? [Any]
        else {
            throw TranslationError.invalidResponse
        }

        let translated = segments.compactMap { segment -> String? in
            guard let pair = segment as? [Any],
                  let text = pair.first as? String
            else { return nil }
            return text
        }

        let result = translated.joined()
        guard !result.isEmpty else {
            throw TranslationError.invalidResponse
        }
        return result
    }

    /// Map app Language enum to Google Translate language codes.
    private func languageCode(for language: Language) -> String {
        switch language {
        case .autoDetect:         return "auto"
        case .simplifiedChinese:  return "zh-CN"
        case .traditionalChinese: return "zh-TW"
        default:                  return language.rawValue
        }
    }
}
