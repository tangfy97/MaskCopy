import Foundation

/// Check-digit algorithms for personal and document numbers. Each function takes the matched
/// text (separators allowed) and says whether it is a well-formed number of that kind.
public enum Checksum {
    static func digits(_ s: String) -> [Int] { s.compactMap { $0.isASCII ? $0.wholeNumberValue : nil } }

    static func letterValue(_ c: Character) -> Int? {
        guard let a = c.asciiValue, a >= 65, a <= 90 else { return nil }
        return Int(a) - 55 // A = 10 … Z = 35
    }

    static func validDDMM(_ d: [Int], at i: Int = 0) -> Bool {
        let day = d[i] * 10 + d[i + 1], month = d[i + 2] * 10 + d[i + 3]
        return (1...12).contains(month) && (1...31).contains(day)
    }

    static func validYYYYMMDD(_ d: [Int], at i: Int = 0) -> Bool {
        let y = d[i] * 1000 + d[i + 1] * 100 + d[i + 2] * 10 + d[i + 3]
        let m = d[i + 4] * 10 + d[i + 5], day = d[i + 6] * 10 + d[i + 7]
        return (1900...2100).contains(y) && (1...12).contains(m) && (1...31).contains(day)
    }

    static func weighted(_ d: [Int], _ w: [Int]) -> Int { zip(d, w).map(*).reduce(0, +) }

    public static func luhn(_ d: [Int]) -> Bool {
        var sum = 0
        for (i, x) in d.reversed().enumerated() {
            var v = x
            if i % 2 == 1 { v *= 2; if v > 9 { v -= 9 } }
            sum += v
        }
        return sum % 10 == 0
    }

    // MARK: Europe

    /// Netherlands, burgerservicenummer: the 11-proef.
    public static func dutchBSN(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 9 else { return false }
        let sum = weighted(d, [9, 8, 7, 6, 5, 4, 3, 2]) - d[8]
        return sum != 0 && sum % 11 == 0
    }

    /// Belgium, rijksregisternummer / numéro national.
    public static func belgianNationalNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11, let base = Int(d[0..<9].map(String.init).joined()) else { return false }
        let check = d[9] * 10 + d[10]
        return 97 - base % 97 == check || 97 - (2_000_000_000 + base) % 97 == check
    }

    /// Italy, codice fiscale (with omocodia letters in digit positions).
    public static func italianFiscalCode(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 16 else { return false }
        let odd = [1, 0, 5, 7, 9, 13, 15, 17, 19, 21, 2, 4, 18, 20, 11, 3, 6, 8, 12, 14, 16, 10, 22, 25, 24, 23]
        var sum = 0
        for i in 0..<15 {
            let v: Int
            if let n = c[i].wholeNumberValue { v = n } else if let l = letterValue(c[i]) { v = l - 10 } else { return false }
            sum += i % 2 == 0 ? odd[v] : v
        }
        return c[15] == Character(UnicodeScalar(UInt8(65 + sum % 26)))
    }

    /// Spain, DNI and NIE.
    public static func spanishDNI(_ s: String) -> Bool {
        var t = s.uppercased().filter { $0.isLetter || $0.isNumber }
        guard t.count == 9, let first = t.first else { return false }
        if let i = "XYZ".firstIndex(of: first) { t = String("XYZ".distance(from: "XYZ".startIndex, to: i)) + t.dropFirst() }
        guard let n = Int(t.prefix(8)) else { return false }
        return t.last == Array("TRWAGMYFPDXBNJZSQVHLCKE")[n % 23]
    }

    /// Portugal, NIF.
    public static func portugueseNIF(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 9, [1, 2, 3, 5, 6, 8, 9].contains(d[0]) else { return false }
        var c = 11 - weighted(d, [9, 8, 7, 6, 5, 4, 3, 2]) % 11
        if c >= 10 { c = 0 }
        return c == d[8]
    }

    /// Portugal, Cartão de Cidadão document number (12 characters).
    public static func portugueseCitizenCard(_ s: String) -> Bool {
        let c = Array(s.uppercased().filter { $0.isLetter || $0.isNumber })
        guard c.count == 12 else { return false }
        var sum = 0
        for (i, ch) in c.reversed().enumerated() {
            guard var v = ch.wholeNumberValue ?? letterValue(ch) else { return false }
            if i % 2 == 1 { v *= 2; if v >= 10 { v -= 9 } }
            sum += v
        }
        return sum % 10 == 0
    }

    /// Sweden, personnummer.
    public static func swedishPersonalNumber(_ s: String) -> Bool {
        var d = digits(s)
        if d.count == 12 { d = Array(d.dropFirst(2)) }
        guard d.count == 10 else { return false }
        let month = d[2] * 10 + d[3], day = d[4] * 10 + d[5]
        guard (1...12).contains(month), (1...31).contains(day) || (61...91).contains(day) else { return false }
        return luhn(d)
    }

    public static func norwegianControlDigits(_ d: [Int]) -> (Int, Int)? {
        guard d.count == 9 else { return nil }
        var k1 = 11 - weighted(d, [3, 7, 6, 1, 8, 9, 4, 5, 2]) % 11
        if k1 == 11 { k1 = 0 }
        if k1 == 10 { return nil }
        var k2 = 11 - weighted(d + [k1], [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]) % 11
        if k2 == 11 { k2 = 0 }
        if k2 == 10 { return nil }
        return (k1, k2)
    }

    /// Norway, fødselsnummer and D-nummer.
    public static func norwegianBirthNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11, let k = norwegianControlDigits(Array(d[0..<9])) else { return false }
        return k.0 == d[9] && k.1 == d[10]
    }

    /// Denmark, CPR (no reliable check digit since 2007, so only the date is checked).
    public static func danishCPR(_ s: String) -> Bool {
        let d = digits(s)
        return d.count == 10 && validDDMM(d)
    }

    /// Finland, henkilötunnus.
    public static func finnishPersonalCode(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 11, let n = Int(String(c[0..<6]) + String(c[7..<10])) else { return false }
        return c[10] == Array("0123456789ABCDEFHJKLMNPRSTUVWXY")[n % 31] && validDDMM(digits(String(c[0..<6])))
    }

    /// Iceland, kennitala.
    public static func icelandicKennitala(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 10 else { return false }
        var r = 11 - weighted(d, [3, 2, 7, 6, 5, 4, 3, 2]) % 11
        if r == 11 { r = 0 }
        return r != 10 && r == d[8] && validDDMM(d)
    }

    /// Estonia and Lithuania, isikukood / asmens kodas.
    public static func balticPersonalCode(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11, (1...6).contains(d[0]) else { return false }
        var r = weighted(d, [1, 2, 3, 4, 5, 6, 7, 8, 9, 1]) % 11
        if r == 10 {
            r = weighted(d, [3, 4, 5, 6, 7, 8, 9, 1, 2, 3]) % 11
            if r == 10 { r = 0 }
        }
        return r == d[10]
    }

    /// Latvia, personas kods (codes from 2017 start with 32 and have no check digit).
    public static func latvianPersonalCode(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11 else { return false }
        if d[0] == 3 && d[1] == 2 { return true }
        return (1101 - weighted(d, [1, 6, 3, 7, 9, 10, 5, 8, 4, 2])) % 11 == d[10] && validDDMM(d)
    }

    /// Poland, PESEL.
    public static func polishPESEL(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11 else { return false }
        return (10 - weighted(d, [1, 3, 7, 9, 1, 3, 7, 9, 1, 3]) % 10) % 10 == d[10]
    }

    /// Czechia and Slovakia, rodné číslo.
    public static func czechBirthNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 10, let n = Int(d.map(String.init).joined()) else { return false }
        return n % 11 == 0 || ((n / 10) % 11 == 10 && d[9] == 0)
    }

    /// Romania, CNP.
    public static func romanianCNP(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 13, d[0] != 0 else { return false }
        var r = weighted(d, [2, 7, 9, 1, 4, 6, 3, 5, 8, 2, 7, 9]) % 11
        if r == 10 { r = 1 }
        return r == d[12]
    }

    /// Bulgaria, EGN.
    public static func bulgarianEGN(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 10 else { return false }
        var r = weighted(d, [2, 4, 8, 5, 10, 9, 7, 3, 6]) % 11
        if r == 10 { r = 0 }
        return r == d[9]
    }

    /// Croatia, OIB (ISO 7064, MOD 11,10).
    public static func croatianOIB(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11 else { return false }
        var a = 10
        for x in d[0..<10] {
            a = (a + x) % 10
            if a == 0 { a = 10 }
            a = (a * 2) % 11
        }
        var c = 11 - a
        if c == 10 { c = 0 }
        return c == d[10]
    }

    /// Former Yugoslavia, JMBG / EMŠO (Slovenia, Serbia, North Macedonia, Montenegro, Bosnia and Herzegovina).
    public static func yugoslavJMBG(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 13 else { return false }
        var m = 11 - weighted(d, [7, 6, 5, 4, 3, 2, 7, 6, 5, 4, 3, 2]) % 11
        if m > 9 { m = 0 }
        return m == d[12] && validDDMM(d)
    }

    /// Ireland, PPS number.
    public static func irishPPS(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 8 || c.count == 9 else { return false }
        let d = c[0..<7].compactMap(\.wholeNumberValue)
        guard d.count == 7 else { return false }
        var sum = weighted(d, [8, 7, 6, 5, 4, 3, 2])
        if c.count == 9, c[8] != "W" {
            guard let a = c[8].asciiValue else { return false }
            sum += (Int(a) - 64) * 9
        }
        return c[7] == Array("WABCDEFGHIJKLMNOPQRSTUV")[sum % 23]
    }

    /// EAN-13 check digit, used by the Swiss AHV/AVS number.
    public static func ean13(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 13 else { return false }
        let sum = d[0..<12].enumerated().map { $0.offset % 2 == 0 ? $0.element : $0.element * 3 }.reduce(0, +)
        return (10 - sum % 10) % 10 == d[12]
    }

    /// Türkiye, T.C. Kimlik No.
    public static func turkishIdentityNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11, d[0] != 0 else { return false }
        let odd = d[0] + d[2] + d[4] + d[6] + d[8], even = d[1] + d[3] + d[5] + d[7]
        return ((odd * 7 - even) % 10 + 10) % 10 == d[9] && d[0..<10].reduce(0, +) % 10 == d[10]
    }

    /// Moldova, IDNP.
    public static func moldovanIDNP(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 13, d[0] == 0 || d[0] == 2 else { return false }
        var sum = 0
        for i in 0..<12 { sum += d[i] * [7, 3, 1][i % 3] }
        return sum % 10 == d[12]
    }

    /// Ukraine, УНЗР (record number): a date and five digits.
    public static func ukrainianRecordNumber(_ s: String) -> Bool {
        let d = digits(s)
        return d.count == 13 && validYYYYMMDD(d)
    }

    /// Luxembourg, matricule: a date and five digits.
    public static func luxembourgMatricule(_ s: String) -> Bool {
        let d = digits(s)
        return d.count == 13 && validYYYYMMDD(d)
    }

    // MARK: Americas

    public static func usSocialSecurityNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 9 else { return false }
        let area = d[0] * 100 + d[1] * 10 + d[2]
        return area != 0 && area != 666 && area < 900 && !(d[3] == 0 && d[4] == 0) && !d[5...8].allSatisfy { $0 == 0 }
    }

    /// Mexico, CURP.
    public static func mexicanCURP(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 18 else { return false }
        let dict = Array("0123456789ABCDEFGHIJKLMNÑOPQRSTUVWXYZ")
        var sum = 0
        for i in 0..<17 {
            guard let v = dict.firstIndex(of: c[i]) else { return false }
            sum += v * (18 - i)
        }
        return c[17].wholeNumberValue == (10 - sum % 10) % 10
    }

    /// Brazil, CPF.
    public static func brazilianCPF(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 11, Set(d).count > 1 else { return false }
        func check(_ n: Int) -> Int {
            let r = (0..<n).map { d[$0] * (n + 1 - $0) }.reduce(0, +) * 10 % 11
            return r == 10 ? 0 : r
        }
        return check(9) == d[9] && check(10) == d[10]
    }

    // MARK: Asia

    /// China, 居民身份证号码 (ISO 7064 MOD 11-2).
    public static func chineseResidentID(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 18 else { return false }
        let w = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
        var sum = 0
        for i in 0..<17 {
            guard let v = c[i].wholeNumberValue else { return false }
            sum += v * w[i]
        }
        let birth = c[6..<14].compactMap(\.wholeNumberValue)
        return c[17] == Array("10X98765432")[sum % 11] && birth.count == 8 && validYYYYMMDD(birth)
    }

    /// Hong Kong identity card number.
    public static func hongKongID(_ s: String) -> Bool {
        let c = Array(s.uppercased().filter { $0.isLetter || $0.isNumber })
        guard c.count == 8 || c.count == 9 else { return false }
        let letters = c.count == 9 ? 2 : 1
        var sum: Int
        if letters == 2 {
            guard let a = letterValue(c[0]), let b = letterValue(c[1]) else { return false }
            sum = a * 9 + b * 8
        } else {
            guard let a = letterValue(c[0]) else { return false }
            sum = 36 * 9 + a * 8
        }
        let d = c[letters..<(letters + 6)].compactMap(\.wholeNumberValue)
        guard d.count == 6 else { return false }
        for (i, x) in d.enumerated() { sum += x * (7 - i) }
        let r = 11 - sum % 11
        let expected: Character = r == 11 ? "0" : r == 10 ? "A" : Character(String(r))
        return c.last == expected
    }

    /// Taiwan, 國民身分證統一編號.
    public static func taiwanID(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 10 else { return false }
        let codes: [Character: Int] = [
            "A": 10, "B": 11, "C": 12, "D": 13, "E": 14, "F": 15, "G": 16, "H": 17, "I": 34, "J": 18, "K": 19, "L": 20, "M": 21,
            "N": 22, "O": 35, "P": 23, "Q": 24, "R": 25, "S": 26, "T": 27, "U": 28, "V": 29, "W": 32, "X": 30, "Y": 31, "Z": 33,
        ]
        guard let n = codes[c[0]] else { return false }
        let d = c[1...].compactMap(\.wholeNumberValue)
        guard d.count == 9 else { return false }
        return (n / 10 + (n % 10) * 9 + weighted(d, [8, 7, 6, 5, 4, 3, 2, 1, 1])) % 10 == 0
    }

    /// Japan, 個人番号 (My Number).
    public static func japaneseMyNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 12 else { return false }
        var sum = 0
        for n in 1...11 { sum += d[11 - n] * (n <= 6 ? n + 1 : n - 5) }
        let r = sum % 11
        return (r <= 1 ? 0 : 11 - r) == d[11]
    }

    /// South Korea, 주민등록번호 (numbers issued since 2020 have no check digit, so only the date and the seventh digit are checked).
    public static func koreanResidentNumber(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 13, (1...8).contains(d[6]) else { return false }
        let m = d[2] * 10 + d[3], day = d[4] * 10 + d[5]
        return (1...12).contains(m) && (1...31).contains(day)
    }

    /// Singapore, NRIC and FIN.
    public static func singaporeNRIC(_ s: String) -> Bool {
        let c = Array(s.uppercased())
        guard c.count == 9 else { return false }
        let d = c[1..<8].compactMap(\.wholeNumberValue)
        guard d.count == 7 else { return false }
        var sum = weighted(d, [2, 7, 6, 5, 4, 3, 2])
        switch c[0] {
        case "S": return c[8] == Array("JZIHGFEDCBA")[sum % 11]
        case "T": sum += 4; return c[8] == Array("JZIHGFEDCBA")[sum % 11]
        case "F": return c[8] == Array("XWUTRQPNMLK")[sum % 11]
        case "G": sum += 4; return c[8] == Array("XWUTRQPNMLK")[sum % 11]
        case "M": return c[8].isLetter
        default: return false
        }
    }

    /// Malaysia, MyKad number: a date, a place-of-birth code and four digits.
    public static func malaysianNRIC(_ s: String) -> Bool {
        let d = digits(s)
        guard d.count == 12 else { return false }
        let m = d[2] * 10 + d[3], day = d[4] * 10 + d[5]
        return (1...12).contains(m) && (1...31).contains(day)
    }

    /// India, Aadhaar (Verhoeff).
    public static func verhoeff(_ s: String) -> Bool {
        let d = digits(s)
        guard !d.isEmpty else { return false }
        let m: [[Int]] = [
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 2, 3, 4, 0, 6, 7, 8, 9, 5], [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
            [3, 4, 0, 1, 2, 8, 9, 5, 6, 7], [4, 0, 1, 2, 3, 9, 5, 6, 7, 8], [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
            [6, 5, 9, 8, 7, 1, 0, 4, 3, 2], [7, 6, 5, 9, 8, 2, 1, 0, 4, 3], [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
            [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
        ]
        let p: [[Int]] = [
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 5, 7, 6, 2, 8, 3, 0, 9, 4], [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
            [8, 9, 1, 6, 0, 4, 3, 5, 2, 7], [9, 4, 5, 3, 1, 2, 6, 8, 7, 0], [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
            [2, 7, 9, 3, 8, 0, 6, 4, 1, 5], [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
        ]
        var c = 0
        for (i, x) in d.reversed().enumerated() { c = m[c][p[i % 8][x]] }
        return c == 0
    }

    // MARK: Machine-readable zone

    /// ICAO 9303 check digit (weights 7, 3, 1).
    public static func mrzCheckDigit<S: Sequence>(_ s: S) -> Int where S.Element == Character {
        var sum = 0
        for (i, ch) in s.enumerated() {
            let v: Int
            if let n = ch.wholeNumberValue { v = n } else if let l = letterValue(ch) { v = l } else { v = 0 }
            sum += v * [7, 3, 1][i % 3]
        }
        return sum % 10
    }
}
