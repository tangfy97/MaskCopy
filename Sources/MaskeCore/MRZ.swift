import CoreGraphics
import Foundation

/// The machine-readable zone of an ICAO 9303 document (passports TD3, ID cards TD1, TD2),
/// or the single line of an ISO 18013 driving licence.
public struct MRZ: Sendable, Equatable {
    public enum Format: String, Sendable { case td1, td2, td3, licence }

    public let format: Format
    public let documentCode: String
    public let issuingState: String
    public let documentNumber: String
    public let personalNumber: String?
    public let checksumsValid: Bool
    public let lines: [String]

    public var documentKind: DocumentKind {
        if format == .licence { return .drivingLicence }
        let code = documentCode.replacingOccurrences(of: "<", with: "")
        if code.hasPrefix("P") { return .passport }
        if code.hasPrefix("V") { return .unknown }
        if code.count == 2 && (code.hasSuffix("R") || code == "RP") || code.hasPrefix("R") { return .residencePermit }
        if code.hasPrefix("A") || code.hasPrefix("C") { return .residencePermit }
        return .idCard
    }
}

enum MRZReader {
    static func normalize(_ s: String) -> String {
        var t = s.uppercased()
        for (a, b) in [("«", "<<"), ("‹", "<"), ("く", "<"), ("＜", "<"), ("〈", "<"), ("≪", "<<")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.filter { !$0.isWhitespace }
    }

    static func looksLikeMRZ(_ t: String) -> Bool {
        guard (26...48).contains(t.count) else { return false }
        let allowed = t.allSatisfy { ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "<" }
        return allowed && t.contains("<")
    }

    /// Picks the MRZ lines out of a page and reads them.
    static func find(in lines: [TextLine]) -> (MRZ?, [TextLine]) {
        let candidates = lines
            .map { ($0, normalize($0.text)) }
            .filter { looksLikeMRZ($0.1) }
            .sorted { $0.0.box.minY < $1.0.box.minY }
        guard !candidates.isEmpty else { return (nil, []) }

        // The MRZ is the bottom-most run of such lines that sit close together.
        var group: [(TextLine, String)] = [candidates.last!]
        for c in candidates.dropLast().reversed() {
            let top = group.first!.0
            let gap = top.box.minY - c.0.box.maxY
            if gap < top.box.height * 2.5 { group.insert(c, at: 0) } else { break }
        }
        let texts = group.map(\.1)
        return (parse(texts), group.map(\.0))
    }

    static func fit(_ s: String, _ n: Int) -> [Character] {
        let a = Array(s.prefix(n))
        return a + Array(repeating: "<", count: max(0, n - a.count))
    }

    static func field(_ c: [Character], _ r: Range<Int>) -> String { String(c[r]) }

    static func check(_ c: [Character], _ r: Range<Int>, _ at: Int) -> Bool {
        guard let d = c[at].wholeNumberValue else { return c[at] == "<" && c[r].allSatisfy { $0 == "<" } }
        return Checksum.mrzCheckDigit(c[r]) == d
    }

    static func trim(_ s: String) -> String { s.trimmingCharacters(in: CharacterSet(charactersIn: "<")).replacingOccurrences(of: "<", with: "") }

    static func parse(_ texts: [String]) -> MRZ? {
        let lengths = texts.map(\.count)
        let avg = lengths.reduce(0, +) / max(lengths.count, 1)

        if texts.count >= 3, abs(avg - 30) <= 3 {
            let l = texts.suffix(3).map { fit($0, 30) }
            let l1 = l[0], l2 = l[1]
            var docNumber = field(l1, 5..<14)
            var optional1 = field(l1, 15..<30)
            if l1[14] == "<" { // long document numbers continue in the optional field
                let extra = trim(String(optional1.prefix { $0 != "<" }.dropLast()))
                docNumber = trim(docNumber) + extra
                optional1 = ""
            }
            let personal = [trim(optional1), trim(field(l2, 18..<29))].filter { $0.count >= 6 }.first
            let valid = (l1[14] == "<" || check(l1, 5..<14, 14)) && check(l2, 0..<6, 6) && check(l2, 8..<14, 14)
            return MRZ(format: .td1, documentCode: field(l1, 0..<2), issuingState: field(l1, 2..<5),
                       documentNumber: trim(docNumber), personalNumber: personal, checksumsValid: valid, lines: Array(texts.suffix(3)))
        }
        if texts.count >= 2, abs(avg - 44) <= 4 {
            let l = texts.suffix(2).map { fit($0, 44) }
            let l1 = l[0], l2 = l[1]
            let personal = trim(field(l2, 28..<42))
            let valid = check(l2, 0..<9, 9) && check(l2, 13..<19, 19) && check(l2, 21..<27, 27)
            return MRZ(format: .td3, documentCode: field(l1, 0..<2), issuingState: field(l1, 2..<5),
                       documentNumber: trim(field(l2, 0..<9)), personalNumber: personal.count >= 6 ? personal : nil,
                       checksumsValid: valid, lines: Array(texts.suffix(2)))
        }
        if texts.count >= 2, abs(avg - 36) <= 3 {
            let l = texts.suffix(2).map { fit($0, 36) }
            let l1 = l[0], l2 = l[1]
            let personal = trim(field(l2, 28..<35))
            let valid = check(l2, 0..<9, 9) && check(l2, 13..<19, 19)
            return MRZ(format: .td2, documentCode: field(l1, 0..<2), issuingState: field(l1, 2..<5),
                       documentNumber: trim(field(l2, 0..<9)), personalNumber: personal.count >= 6 ? personal : nil,
                       checksumsValid: valid, lines: Array(texts.suffix(2)))
        }
        if let last = texts.last, last.hasPrefix("D"), abs(last.count - 30) <= 3 {
            let c = fit(last, 30)
            return MRZ(format: .licence, documentCode: "D", issuingState: field(c, 2..<5), documentNumber: trim(field(c, 5..<14)),
                       personalNumber: nil, checksumsValid: false, lines: [last])
        }
        return nil
    }
}
