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

    /// Recognises text in `image`, returning lines sorted top-to-bottom.
    /// Runs on a background thread to avoid blocking the main thread.
    func recognizeText(from image: CGImage) async throws -> String {
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

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OCRError.noTextFound
            }
            return text
        }.value
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
