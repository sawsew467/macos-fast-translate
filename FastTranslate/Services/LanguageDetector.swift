import Foundation

/// Detects whether text is Vietnamese or English using Unicode scalar analysis.
/// Vietnamese-specific scalars: ă, â, đ, ê, ô, ơ, ư and all toned variants (U+1EA0–U+1EF9).
/// Threshold: >5% of letters are Vietnamese-specific → .vietnamese, else → .english
struct LanguageDetector {
    static func detect(_ text: String) -> Language {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .english }

        var letterCount = 0
        var viCount = 0

        for scalar in text.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            letterCount += 1
            if isVietnamese(scalar) { viCount += 1 }
        }

        guard letterCount > 0 else { return .english }
        return Double(viCount) / Double(letterCount) > 0.05 ? .vietnamese : .english
    }

    private static func isVietnamese(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        // U+1EA0–U+1EF9 — Vietnamese vowels with tone marks (Ạ–ỹ)
        if v >= 0x1EA0 && v <= 0x1EF9 { return true }
        // đ (U+0111), Đ (U+0110)
        if v == 0x0111 || v == 0x0110 { return true }
        // ă (U+0103), Ă (U+0102)
        if v == 0x0103 || v == 0x0102 { return true }
        // ơ (U+01A1), Ơ (U+01A0)
        if v == 0x01A1 || v == 0x01A0 { return true }
        // ư (U+01B0), Ư (U+01AF)
        if v == 0x01B0 || v == 0x01AF { return true }
        return false
    }
}
