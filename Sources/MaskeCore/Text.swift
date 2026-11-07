import CoreGraphics
import Foundation
import Vision

/// One recognized line of text: its corners (tilted if the text is) and its upright bounding box,
/// normalized to the page with the origin at the top left.
struct TextLine {
    let text: String
    let quad: Quad
    let candidate: VNRecognizedText?

    var box: CGRect { quad.boundingRect }

    /// The corners of part of the line.
    func quad(for range: Range<String.Index>) -> Quad {
        if range == text.startIndex..<text.endIndex { return quad }
        if let candidate, let o = try? candidate.boundingBox(for: range) {
            let q = Rectifier.quad(o)
            if q.area() > 0 { return q }
        }
        let total = CGFloat(max(text.count, 1))
        let start = CGFloat(text.distance(from: text.startIndex, to: range.lowerBound))
        let length = CGFloat(text.distance(from: range.lowerBound, to: range.upperBound))
        return quad.slice(start / total, (start + length) / total)
    }

    func box(for range: Range<String.Index>) -> CGRect { quad(for: range).boundingRect }

    /// Vision may return the same word box for two characters. Use its cut only when the
    /// nearest non-space characters on either side actually have separate, ordered boxes.
    func cutPoint(at boundary: String.Index) -> CGPoint? {
        guard let candidate,
              let before = text[..<boundary].lastIndex(where: { !$0.isWhitespace }),
              let after = text[boundary...].firstIndex(where: { !$0.isWhitespace }),
              let left = try? candidate.boundingBox(for: before..<text.index(after: before)),
              let right = try? candidate.boundingBox(for: after..<text.index(after: after)) else { return nil }
        let a = Rectifier.quad(left), b = Rectifier.quad(right)
        let end = lerp(a.tr, a.br, 0.5), start = lerp(b.tl, b.bl, 0.5)
        guard a.area() > 0, b.area() > 0, start.x >= end.x,
              start.x - end.x <= box.width * 0.15,
              abs(start.y - end.y) <= box.height * 0.5 else { return nil }
        return lerp(end, start, 0.5)
    }
}

/// A transformed copy of a string (folded, upper-cased, optionally without spaces) that remembers
/// where each of its characters came from, so a match can be mapped back to the original.
struct MappedText {
    let original: String
    let value: String
    private let map: [String.Index]

    /// Cyrillic and Greek letters that OCR returns for Latin ones in numbers ("А123456(3)").
    static let homoglyphs: [Character: Character] = [
        "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T", "Х": "X", "У": "Y",
        "І": "I", "Ј": "J", "Ѕ": "S", "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M", "Ν": "N",
        "Ο": "O", "Ρ": "P", "Τ": "T", "Υ": "Y", "Χ": "X",
    ]

    init(_ s: String, dropSpaces: Bool, digitize: Bool = false, latinize: Bool = false) {
        original = s
        var out = ""
        var map: [String.Index] = []
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            defer { i = s.index(after: i) }
            if dropSpaces && ch.isWhitespace { continue }
            var t = String(ch).folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil).uppercased()
            if latinize || digitize {
                t = String(t.map { MappedText.homoglyphs[$0] ?? $0 })
            }
            if digitize {
                t = String(t.map { c -> Character in
                    switch c {
                    case "O", "D", "Q": return "0"
                    case "I", "L", "|": return "1"
                    default: return c
                    }
                })
            }
            for c in t {
                out.append(c)
                map.append(i)
            }
        }
        value = out
        self.map = map
    }

    func originalRange(_ r: Range<String.Index>) -> Range<String.Index>? {
        let lo = value.distance(from: value.startIndex, to: r.lowerBound)
        let hi = value.distance(from: value.startIndex, to: r.upperBound)
        guard lo < hi, hi <= map.count else { return nil }
        return map[lo]..<original.index(after: map[hi - 1])
    }

    func matches(_ regex: NSRegularExpression) -> [(Range<String.Index>, String)] {
        let ns = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: ns).compactMap { m in
            guard let r = Range(m.range, in: value), let o = originalRange(r) else { return nil }
            return (o, String(value[r]))
        }
    }
}

extension String {
    var foldedUpper: String {
        folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil).uppercased()
    }

    var containsCJK: Bool { unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) || (0xAC00...0xD7AF).contains($0.value) } }
    var containsKana: Bool { unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) } }
    var containsHangul: Bool { unicodeScalars.contains { (0xAC00...0xD7AF).contains($0.value) } }
}

/// Finds `needle` in `haystack` only where it is not part of a longer word.
func tokenRanges(of needle: String, in haystack: String) -> [Range<String.Index>] {
    var out: [Range<String.Index>] = []
    var start = haystack.startIndex
    while start < haystack.endIndex, let r = haystack.range(of: needle, range: start..<haystack.endIndex) {
        let before = r.lowerBound == haystack.startIndex ? nil : haystack[haystack.index(before: r.lowerBound)]
        let after = r.upperBound == haystack.endIndex ? nil : haystack[r.upperBound]
        let needleIsLatin = needle.unicodeScalars.contains { $0.properties.isAlphabetic && $0.value < 0x2E80 }
        func isWordChar(_ c: Character?) -> Bool {
            guard let c, needleIsLatin else { return false }
            return c.isLetter && !String(c).containsCJK
        }
        if !isWordChar(before) && !isWordChar(after) { out.append(r) }
        start = r.upperBound
    }
    return out
}
