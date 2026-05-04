import Foundation
import Vision

// MARK: - OCR Error

enum OCRError: LocalizedError {
    case noTextFound
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noTextFound: return "No text found in the captured region."
        case .recognitionFailed(let e): return "Text recognition failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - OCR Service

/// Extracts text from a CGImage using Apple's Vision framework.
/// Supports common Latin and CJK languages used by the translation flow.
final class OCRService {

    struct RecognizedDocument {
        let text: String
        let presentation: TranslationPresentation

        var translationContext: String? {
            guard presentation == .conversation else { return nil }
            return """
            The OCR text appears to be a chat conversation. Translate each message while preserving speaker names, timestamps, mentions, emojis, and message order. Return the result as a chat transcript using one speaker header per message in this exact shape: [speaker timestamp]
            translated message text
            """
        }
    }

    /// Recognises text in `image`, returning lines sorted top-to-bottom.
    /// Runs on a background thread to avoid blocking the main thread.
    func recognizeText(from image: CGImage) async throws -> String {
        try await recognizeDocument(from: image).text
    }

    /// Recognises text and classifies whether the region looks like chat messages.
    func recognizeDocument(from image: CGImage) async throws -> RecognizedDocument {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = Self.supportedRecognitionLanguages(for: request)

            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw OCRError.recognitionFailed(error)
            }

            guard let observations = request.results, !observations.isEmpty else {
                throw OCRError.noTextFound
            }

            // Vision bounding boxes use bottom-left origin (y=0 at bottom of image),
            // so higher boundingBox.origin.y means higher on screen.
            let text = observations
                .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw OCRError.noTextFound
            }
            return RecognizedDocument(
                text: text,
                presentation: Self.looksLikeConversation(text) ? .conversation : .plain
            )
        }.value
    }

    private static func looksLikeConversation(_ text: String) -> Bool {
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 3 else { return false }
        let timePattern = #"\b\d{1,2}[:.]\d{2}(?:\s?[AP]M)?\b"#
        let speakerTimePattern = #"^[\p{L}\p{N}._-]{2,32}\s+\d{1,2}[:.]\d{2}(?:\s?[AP]M)?\b"#

        let timestampCount = lines.filter {
            $0.range(of: timePattern, options: [.regularExpression, .caseInsensitive]) != nil
        }.count
        let speakerTimeCount = lines.filter { line in
            line.range(of: speakerTimePattern, options: [.regularExpression, .caseInsensitive]) != nil
        }.count
        let shortNameCount = lines.filter { line in
            line.range(of: #"^[\p{L}\p{N}._-]{2,32}$"#, options: .regularExpression) != nil
        }.count
        let mentionCount = lines.filter { $0.contains("@") }.count
        let chatChromeCount = lines.filter { line in
            let lower = line.lowercased()
            return lower.contains("new messages") || lower.contains("reply to") || lower == "thread"
        }.count

        return speakerTimeCount >= 2
            || timestampCount >= 3
            || (timestampCount >= 2 && mentionCount >= 1)
            || (timestampCount >= 1 && shortNameCount >= 2 && mentionCount >= 1)
            || (timestampCount >= 1 && chatChromeCount >= 1)
    }

    /// Keep Vision OCR multilingual, but only pass languages supported by the
    /// current macOS revision. Unsupported hard-coded languages can make CJK
    /// recognition fail before translation starts.
    private static func supportedRecognitionLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let preferredLanguages = [
            "vi-VN", "en-US", "ja-JP", "ko-KR",
            "zh-Hans", "zh-Hant", "fr-FR", "de-DE",
            "es-ES", "pt-BR", "it-IT", "ru-RU",
            "th-TH", "id-ID"
        ]

        do {
            let supported = try request.supportedRecognitionLanguages()
            let filtered = preferredLanguages.filter { supported.contains($0) }
            return filtered.isEmpty ? supported : filtered
        } catch {
            return preferredLanguages
        }
    }
}
