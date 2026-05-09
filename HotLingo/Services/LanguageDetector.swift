import Foundation

/// Lightweight local language detection used to choose a sensible target language
/// before the request is sent to the translation provider.
struct LanguageDetector {
    static func detect(_ text: String) -> Language {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .autoDetect }

        var letterCount = 0
        var vietnameseSpecificCount = 0
        var latinLetterCount = 0
        var hiraganaKatakanaCount = 0
        var hangulCount = 0
        var cjkCount = 0
        var thaiCount = 0
        var cyrillicCount = 0

        for scalar in trimmed.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            letterCount += 1

            switch scalar.value {
            case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
                latinLetterCount += 1
            case 0x3040...0x30FF, 0x31F0...0x31FF:
                hiraganaKatakanaCount += 1
            case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F:
                hangulCount += 1
            case 0x4E00...0x9FFF, 0x3400...0x4DBF:
                cjkCount += 1
            case 0x0E00...0x0E7F:
                thaiCount += 1
            case 0x0400...0x04FF, 0x0500...0x052F:
                cyrillicCount += 1
            default:
                break
            }

            if isVietnameseSpecific(scalar) {
                vietnameseSpecificCount += 1
            }
        }

        guard letterCount > 0 else { return .autoDetect }

        if Double(hiraganaKatakanaCount) / Double(letterCount) > 0.10 { return .japanese }
        if Double(hangulCount) / Double(letterCount) > 0.20 { return .korean }
        if Double(thaiCount) / Double(letterCount) > 0.20 { return .thai }
        if Double(cyrillicCount) / Double(letterCount) > 0.20 { return .russian }
        if Double(cjkCount) / Double(letterCount) > 0.35 { return .simplifiedChinese }

        // Vietnamese OCR often contains enough diacritics to identify locally.
        // ASCII-only Vietnamese cannot be distinguished reliably from English.
        if latinLetterCount > 0 {
            let vietnameseRatio = Double(vietnameseSpecificCount) / Double(latinLetterCount)
            if vietnameseSpecificCount >= 2 || vietnameseRatio >= 0.04 {
                return .vietnamese
            }
        }

        return .english
    }

    private static func isVietnameseSpecific(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0102, 0x0103, // Ăă
             0x00C2, 0x00E2, // Ââ
             0x0110, 0x0111, // Đđ
             0x00CA, 0x00EA, // Êê
             0x00D4, 0x00F4, // Ôô
             0x01A0, 0x01A1, // Ơơ
             0x01AF, 0x01B0, // Ưư
             0x1EA0...0x1EF9:
            return true
        default:
            return false
        }
    }
}
