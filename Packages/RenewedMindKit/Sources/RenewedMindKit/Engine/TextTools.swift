import Foundation

/// Text helpers shared by the offline engines.
public enum TextTools {
    /// Lowercases and normalizes typographic quotes so patterns can match "don't" and "don’t" alike.
    public static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        let replacements: [(String, String)] = [
            ("\u{2019}", "'"), ("\u{2018}", "'"), ("\u{02BC}", "'"), ("\u{2032}", "'"),
            ("\u{201C}", "\""), ("\u{201D}", "\""),
            ("\u{2014}", " - "), ("\u{2013}", " - "),
            ("\n", " "), ("\t", " "),
        ]
        for (from, to) in replacements {
            s = s.replacingOccurrences(of: from, with: to)
        }
        // Collapse runs of spaces.
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// A stable (process-independent) 64-bit FNV-1a hash, used for deterministic choices.
    public static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// Picks an element deterministically based on a seed string.
    public static func pick<T>(_ items: [T], seed: String, salt: String = "") -> T? {
        guard !items.isEmpty else { return nil }
        let index = Int(stableHash(seed + "|" + salt) % UInt64(items.count))
        return items[index]
    }

    /// Trims, collapses whitespace, and caps length (by characters) at a word boundary.
    public static func clean(_ text: String, maxLength: Int = 1_000) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        guard s.count > maxLength else { return s }
        let prefix = String(s.prefix(maxLength))
        if let space = prefix.lastIndex(of: " ") {
            return String(prefix[..<space]) + "…"
        }
        return prefix + "…"
    }
}

/// A compiled, case-insensitive regular expression with a weight.
struct WeightedPattern: @unchecked Sendable {
    let regex: NSRegularExpression
    let weight: Int

    init(_ pattern: String, weight: Int) {
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            preconditionFailure("Invalid regex \(pattern): \(error)")
        }
        self.weight = weight
    }

    /// Returns the first matched substring, if any.
    func firstMatch(in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    func matches(_ text: String) -> Bool { firstMatch(in: text) != nil }
}
