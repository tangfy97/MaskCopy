import Foundation

/// A personal or document number that can be recognized wherever it is printed:
/// a pattern, and a check (usually a check digit) that rules out most look-alikes.
struct NumberPattern {
    enum Strength {
        /// Distinctive enough to look for on any document.
        case strong
        /// Only on documents from `countries`, or when the country is unknown.
        case countryGated
    }

    let name: String
    let countries: Set<String>
    let kind: FindingKind
    let strength: Strength
    let regex: NSRegularExpression
    /// Look in a copy where O/I/L read as 0/1 (for patterns made only of digits).
    let numeric: Bool
    let validate: (String) -> Bool

    init(_ name: String, _ countries: Set<String>, _ strength: Strength, _ pattern: String,
         kind: FindingKind = .personalNumber, numeric: Bool = false, _ validate: @escaping (String) -> Bool) {
        self.name = name
        self.countries = countries
        self.kind = kind
        self.strength = strength
        let b = "(?<![A-Z0-9])", e = "(?![A-Z0-9])"
        self.regex = try! NSRegularExpression(pattern: b + pattern + e)
        self.numeric = numeric
        self.validate = validate
    }

    func applies(to country: String?) -> Bool {
        switch strength {
        case .strong: return true
        case .countryGated: return country == nil || countries.contains(country!)
        }
    }
}

extension NumberPattern {
    static let jmbgCountries: Set<String> = ["SI", "RS", "MK", "ME", "BA", "HR"]

    static let all: [NumberPattern] = [
        // Europe
        NumberPattern("NL BSN", ["NL"], .countryGated, #"(?:\d{9}|\d{4}\.\d{2}\.\d{3})"#, numeric: true, Checksum.dutchBSN),
        NumberPattern("BE national number", ["BE"], .countryGated, #"\d{2}\.?\d{2}\.?\d{2}-?\d{3}\.?\d{2}"#, numeric: true, Checksum.belgianNationalNumber),
        NumberPattern("IT codice fiscale", ["IT"], .strong, #"[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-EHLMPRST][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]"#, Checksum.italianFiscalCode),
        NumberPattern("ES DNI", ["ES"], .strong, #"\d{8}-?[A-Z]"#, Checksum.spanishDNI),
        NumberPattern("ES NIE", ["ES"], .strong, #"[XYZ]-?\d{7}-?[A-Z]"#, Checksum.spanishDNI),
        NumberPattern("PT NIF", ["PT"], .countryGated, #"\d{9}"#, numeric: true, Checksum.portugueseNIF),
        NumberPattern("PT Cartão de Cidadão", ["PT"], .countryGated, #"\d{8}\s?\d\s?[A-Z0-9]{2}\d"#, Checksum.portugueseCitizenCard),
        NumberPattern("SE personnummer", ["SE"], .countryGated, #"(?:19|20)?\d{6}[-+]\d{4}"#, Checksum.swedishPersonalNumber),
        NumberPattern("SE personnummer", ["SE"], .countryGated, #"(?:19|20)\d{10}"#, numeric: true, Checksum.swedishPersonalNumber),
        NumberPattern("NO fødselsnummer", ["NO"], .countryGated, #"\d{6}\s?\d{5}"#, numeric: true, Checksum.norwegianBirthNumber),
        NumberPattern("DK CPR", ["DK"], .countryGated, #"\d{6}-\d{4}"#, Checksum.danishCPR),
        NumberPattern("FI henkilötunnus", ["FI"], .strong, #"\d{6}[-+A-FU-Y]\d{3}[0-9A-Y]"#, Checksum.finnishPersonalCode),
        NumberPattern("IS kennitala", ["IS"], .countryGated, #"\d{6}-?\d{4}"#, Checksum.icelandicKennitala),
        NumberPattern("EE/LT personal code", ["EE", "LT"], .countryGated, #"[1-6]\d{10}"#, numeric: true, Checksum.balticPersonalCode),
        NumberPattern("LV personas kods", ["LV"], .countryGated, #"\d{6}-\d{5}"#, Checksum.latvianPersonalCode),
        NumberPattern("PL PESEL", ["PL"], .countryGated, #"\d{11}"#, numeric: true, Checksum.polishPESEL),
        NumberPattern("CZ/SK rodné číslo", ["CZ", "SK"], .countryGated, #"\d{6}/\d{3,4}"#, Checksum.czechBirthNumber),
        NumberPattern("RO CNP", ["RO"], .countryGated, #"[1-9]\d{12}"#, numeric: true, Checksum.romanianCNP),
        NumberPattern("BG EGN", ["BG"], .countryGated, #"\d{10}"#, numeric: true, Checksum.bulgarianEGN),
        NumberPattern("HR OIB", ["HR"], .countryGated, #"\d{11}"#, numeric: true, Checksum.croatianOIB),
        NumberPattern("JMBG / EMŠO", jmbgCountries, .countryGated, #"\d{13}"#, numeric: true, Checksum.yugoslavJMBG),
        NumberPattern("IE PPS", ["IE"], .countryGated, #"\d{7}[A-W][A-IW]?"#, Checksum.irishPPS),
        NumberPattern("MT identity number", ["MT"], .countryGated, #"\d{3,7}[MGAPLHBZ]"#, { _ in true }),
        NumberPattern("LU matricule", ["LU"], .countryGated, #"(?:19|20)\d{11}"#, numeric: true, Checksum.luxembourgMatricule),
        NumberPattern("CH AHV/AVS", ["CH", "LI"], .strong, #"756\.?\d{4}\.?\d{4}\.?\d{2}"#, Checksum.ean13),
        NumberPattern("GB driving licence", ["GB"], .strong, #"[A-Z9]{5}\d{6}[A-Z9]{2}\d[A-Z]{2}"#, kind: .documentNumber, { _ in true }),
        NumberPattern("TR kimlik", ["TR"], .countryGated, #"[1-9]\d{10}"#, numeric: true, Checksum.turkishIdentityNumber),
        NumberPattern("UA УНЗР", ["UA"], .countryGated, #"\d{8}-\d{5}"#, Checksum.ukrainianRecordNumber),
        NumberPattern("MD IDNP", ["MD"], .countryGated, #"[02]\d{12}"#, numeric: true, Checksum.moldovanIDNP),
        NumberPattern("AL personal number", ["AL"], .countryGated, #"[A-T]\d{8}[A-W]"#, { _ in true }),
        NumberPattern("BY personal number", ["BY"], .strong, #"\d{7}[A-Z]\d{3}[A-Z]{2}\d"#, { _ in true }),
        // Americas
        NumberPattern("US SSN", ["US"], .countryGated, #"\d{3}-\d{2}-\d{4}"#, Checksum.usSocialSecurityNumber),
        NumberPattern("CA Ontario licence", ["CA"], .strong, #"[A-Z]\d{4}-?\d{5}-?\d{5}"#, kind: .documentNumber, { _ in true }),
        NumberPattern("MX CURP", ["MX"], .strong, #"[A-Z]{4}\d{6}[HMX][A-Z]{5}[0-9A-Z]\d"#, Checksum.mexicanCURP),
        NumberPattern("BR CPF", ["BR"], .countryGated, #"\d{3}\.?\d{3}\.?\d{3}-?\d{2}"#, Checksum.brazilianCPF),
        // Oceania
        NumberPattern("NZ licence", ["NZ"], .countryGated, #"[A-Z]{2}\d{6}"#, kind: .documentNumber, { _ in true }),
        // Asia
        NumberPattern("CN 身份证号", ["CN"], .strong, #"\d{17}[\dX]"#, Checksum.chineseResidentID),
        NumberPattern("HK identity card", ["HK"], .strong, #"[A-Z]{1,2}\d{6}\(?[0-9A]\)?"#, Checksum.hongKongID),
        NumberPattern("TW 身分證", ["TW"], .strong, #"[A-Z][12]\d{8}"#, Checksum.taiwanID),
        NumberPattern("JP 個人番号", ["JP"], .countryGated, #"\d{4}\s?\d{4}\s?\d{4}"#, numeric: true, Checksum.japaneseMyNumber),
        NumberPattern("JP 在留カード", ["JP"], .strong, #"[A-Z]{2}\d{8}[A-Z]{2}"#, kind: .documentNumber, { _ in true }),
        NumberPattern("KR 주민등록번호", ["KR"], .countryGated, #"\d{6}-[1-8]\d{6}"#, Checksum.koreanResidentNumber),
        NumberPattern("KR 운전면허번호", ["KR"], .strong, #"\d{2}-\d{2}-\d{6}-\d{2}"#, kind: .documentNumber, { _ in true }),
        NumberPattern("SG NRIC/FIN", ["SG"], .strong, #"[STFGM]\d{7}[A-Z]"#, Checksum.singaporeNRIC),
        NumberPattern("MY MyKad", ["MY"], .countryGated, #"\d{6}-\d{2}-\d{4}"#, Checksum.malaysianNRIC),
        NumberPattern("MY MyKad", ["MY"], .countryGated, #"\d{12}"#, numeric: true, Checksum.malaysianNRIC),
        NumberPattern("IN Aadhaar", ["IN"], .countryGated, #"[2-9]\d{3}\s?\d{4}\s?\d{4}"#, numeric: true, Checksum.verhoeff),
        NumberPattern("IN PAN", ["IN"], .strong, #"[A-Z]{3}[ABCFGHLJPT][A-Z]\d{4}[A-Z]"#, { _ in true }),
    ]
}
