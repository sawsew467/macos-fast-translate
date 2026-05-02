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
/// Supports Vietnamese diacritics (vi-VN) and English (en-US).
final class OCRService {

    /// Recognises text in `image`, returning lines sorted top-to-bottom.
    /// Runs on a background thread to avoid blocking the main thread.
    func recognizeText(from image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["vi-VN", "en-US"]
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
}
