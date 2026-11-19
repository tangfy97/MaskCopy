import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO
import MaskeCore
import UniformTypeIdentifiers

/// Synthetic documents with made-up people and valid check digits, and the boxes that must be
/// hidden (or must stay visible) on each. Never put a real person's document in the repository.
struct Expected: Codable {
    struct Box: Codable {
        var kind: String
        var rect: CGRect
        var text: String
    }

    var name: String
    var kind: String
    var country: String
    var hide: [Box]
    var keep: [Box]
    var file: String? = nil
}

enum Role {
    case plain
    case keep
    case hide(FindingKind)
}

final class Doc {
    let name: String
    let kind: DocumentKind
    let country: String
    let size: CGSize
    let tint: (CGFloat, CGFloat, CGFloat)
    var items: [(String, CGPoint, CGFloat, String, Role)] = [] // text, origin (fraction), size, font, role
    /// Items laid out right to left: their x is the right edge, and "label|value" puts the value left of the label.
    var rightToLeft: Set<Int> = []
    var photos: [(CGRect, Role)] = []
    var barcode: (CGRect, String)?

    init(_ name: String, _ kind: DocumentKind, _ country: String, passport: Bool = false, tint: (CGFloat, CGFloat, CGFloat) = (0.93, 0.95, 0.96)) {
        self.name = name
        self.kind = kind
        self.country = country
        self.size = passport ? CGSize(width: 1500, height: 1056) : CGSize(width: 1400, height: 882)
        self.tint = tint
    }

    @discardableResult
    func t(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 30, _ role: Role = .plain, font: String = "Helvetica") -> Doc {
        items.append((s, CGPoint(x: x, y: y), size, font, role))
        return self
    }

    func label(_ s: String, _ x: CGFloat, _ y: CGFloat) -> Doc { t(s, x, y, 21, .plain) }
    func value(_ s: String, _ x: CGFloat, _ y: CGFloat, _ role: Role = .keep) -> Doc { t(s, x, y, 32, role, font: "Helvetica-Bold") }

    /// A label with its value on the line below.
    func field(_ l: String, _ v: String, _ x: CGFloat, _ y: CGFloat, _ role: Role = .keep) -> Doc {
        label(l, x, y).value(v, x, y + 0.04)
        if case .keep = role { return self }
        items[items.count - 1].4 = role
        return self
    }

    func mrz(_ lines: [String]) -> Doc {
        let fontSize: CGFloat = lines.count == 3 ? 58 : 50
        let lineHeight: CGFloat = lines.count == 3 ? 0.085 : 0.075
        let top = 0.97 - lineHeight * CGFloat(lines.count)
        for (i, l) in lines.enumerated() {
            t(l, 0.04, top + CGFloat(i) * lineHeight, fontSize, .hide(.machineReadableZone), font: "Menlo")
        }
        return self
    }

    func portrait(_ r: CGRect, _ role: Role = .plain) -> Doc { photos.append((r, role)); return self }

    /// Arabic text ending at `right`.
    @discardableResult
    func ar(_ s: String, _ right: CGFloat, _ y: CGFloat, _ size: CGFloat = 30, _ role: Role = .plain, bold: Bool = false) -> Doc {
        rightToLeft.insert(items.count)
        return t(s, right, y, size, role, font: bold ? "GeezaPro-Bold" : "GeezaPro")
    }
}

enum MRZBuilder {
    static func pad(_ s: String, _ n: Int) -> String { String((s + String(repeating: "<", count: n)).prefix(n)) }
    static func cd(_ s: String) -> String { String(Checksum.mrzCheckDigit(Array(s))) }

    static func td3(state: String, surname: String, given: String, doc: String, nat: String, dob: String, sex: String, exp: String, personal: String = "") -> [String] {
        let l1 = pad("P<" + state + surname + "<<" + given.replacingOccurrences(of: " ", with: "<"), 44)
        let d = pad(doc, 9), p = pad(personal, 14)
        let pcd = personal.isEmpty ? "<" : cd(p)
        let body = d + cd(d) + nat + dob + cd(dob) + sex + exp + cd(exp) + p + pcd
        let composite = cd(d + cd(d) + dob + cd(dob) + exp + cd(exp) + p + pcd)
        return [l1, body + composite]
    }

    static func td1(code: String = "I<", state: String, doc: String, optional: String = "", dob: String, sex: String, exp: String, nat: String, surname: String, given: String) -> [String] {
        let d = pad(doc, 9)
        let l1 = code + state + d + cd(d) + pad(optional, 15)
        let l2head = dob + cd(dob) + sex + exp + cd(exp) + nat + pad("", 11)
        let composite = cd(Array(l1)[5..<30].map(String.init).joined() + Array(l2head)[0..<7].map(String.init).joined()
            + Array(l2head)[8..<15].map(String.init).joined() + Array(l2head)[18..<29].map(String.init).joined())
        let l3 = pad(surname + "<<" + given.replacingOccurrences(of: " ", with: "<"), 30)
        return [l1, l2head + composite, l3]
    }
}

enum Fixtures {
    static func norwegianNumber() -> String {
        for last in 0...99 {
            let d = [1, 5, 0, 7, 8, 5, 4, last / 10, last % 10]
            if let k = Checksum.norwegianControlDigits(d) { return d.map(String.init).joined() + "\(k.0)\(k.1)" }
        }
        fatalError()
    }

    static func belgianNumber() -> String {
        let base = 850_730_033
        let c = 97 - base % 97
        return "85.07.30-033.\(String(format: "%02d", c))"
    }

    static let left = CGRect(x: 0.04, y: 0.22, width: 0.25, height: 0.58)

    static var all: [Doc] {
        let fnr = norwegianNumber()
        let rrn = belgianNumber()
        var docs: [Doc] = []

        // MARK: Passports (ICAO 9303 TD3)
        func passport(_ name: String, _ state: String, _ country: String, title: String, surname: String, given: String, doc: String,
                      personal: String = "", personalLabel: String? = nil, labels: (String, String, String) = ("Surname", "Given names", "Passport No.")) -> Doc {
            let d = Doc(name, .passport, country, passport: true, tint: (0.94, 0.93, 0.95))
                .t(title, 0.36, 0.05, 30, .plain, font: "Helvetica-Bold")
                .portrait(CGRect(x: 0.04, y: 0.16, width: 0.27, height: 0.56), .hide(.photo))
                .field(labels.0, surname, 0.36, 0.14)
                .field(labels.1, given, 0.36, 0.25)
                .field("Nationality", state, 0.36, 0.36)
                .field("Date of birth", "15 JUL 1985", 0.36, 0.47)
                .field(labels.2, doc, 0.72, 0.14, .hide(.documentNumber))
                .field("Date of expiry", "01 JAN 2034", 0.72, 0.47)
            if let personalLabel { d.field(personalLabel, personal, 0.72, 0.25, .hide(.personalNumber)) }
            return d.mrz(MRZBuilder.td3(state: state, surname: surname.replacingOccurrences(of: " ", with: "<"), given: given, doc: doc,
                                        nat: state, dob: "850715", sex: "F", exp: "340101", personal: personal))
        }
        docs.append(passport("passport-nor", "NOR", "NO", title: "NORGE NOREG NORWAY  PASS", surname: "NORDMANN", given: "KARI",
                             doc: "FC1234567", personal: fnr, personalLabel: "Fødselsnummer / Personal No."))
        docs.append(passport("passport-nld", "NLD", "NL", title: "KONINKRIJK DER NEDERLANDEN  PASPOORT", surname: "DE VRIES", given: "ANNA",
                             doc: "SPECI2021", personal: "111222333", personalLabel: "Persoonsnummer / Personal No."))
        docs.append(passport("passport-deu", "D<<", "DE", title: "BUNDESREPUBLIK DEUTSCHLAND  REISEPASS", surname: "MUSTERMANN", given: "ERIKA",
                             doc: "C01X00T47", labels: ("Name / Surname", "Vornamen / Given names", "Pass-Nr. / Passport No.")))
        docs.append(passport("passport-usa", "USA", "US", title: "UNITED STATES OF AMERICA  PASSPORT", surname: "DOE", given: "JANE",
                             doc: "963545637"))
        docs.append(passport("passport-gbr", "GBR", "GB", title: "UNITED KINGDOM OF GREAT BRITAIN  PASSPORT", surname: "MORGAN", given: "SARAH",
                             doc: "925665416"))
        docs.append(passport("passport-chn", "CHN", "CN", title: "中华人民共和国  护照  PASSPORT", surname: "ZHANG", given: "WEI",
                             doc: "EA1234567", labels: ("姓/Surname", "名/Given names", "护照号/Passport No.")))
        docs.append(passport("passport-jpn", "JPN", "JP", title: "日本国  旅券  PASSPORT  JAPAN", surname: "YAMADA", given: "HANAKO",
                             doc: "TR1234567"))
        docs.append(passport("passport-kor", "KOR", "KR", title: "대한민국  여권  REPUBLIC OF KOREA", surname: "HONG", given: "GILDONG",
                             doc: "M12345678"))
        docs.append(passport("passport-aus", "AUS", "AU", title: "AUSTRALIA  PASSPORT", surname: "CITIZEN", given: "JOHN",
                             doc: "PA1234567"))
        docs.append(passport("passport-sgp", "SGP", "SG", title: "REPUBLIC OF SINGAPORE  PASSPORT", surname: "TAN", given: "MEI LING",
                             doc: "K1234567A", personal: "S1234567D", personalLabel: "NRIC No."))

        // MARK: European ID cards (TD1)
        docs.append(Doc("id-nor-front", .idCard, "NO")
            .t("NORGE NOREG NORWAY", 0.04, 0.04, 30)
            .t("ID-KORT / IDENTITY CARD", 0.44, 0.04, 28)
            .field("Etternavn / Surname", "NORDMANN", 0.43, 0.17)
            .field("Fornavn / Given names", "KARI", 0.43, 0.29)
            .field("Dokumentnr / Document no.", "JG1234567", 0.43, 0.57, .hide(.documentNumber))
            .field("CAN", "123456", 0.79, 0.82, .hide(.cardAccessNumber))
            .portrait(CGRect(x: 0.04, y: 0.22, width: 0.35, height: 0.70), .plain)
            .portrait(CGRect(x: 0.70, y: 0.30, width: 0.13, height: 0.28), .hide(.photo)))
        docs.append(Doc("id-nor-back", .idCard, "NO")
            .field("Fødselsnummer / National ID number", fnr, 0.04, 0.05, .hide(.personalNumber))
            .portrait(CGRect(x: 0.18, y: 0.30, width: 0.13, height: 0.28), .hide(.photo))
            .mrz(MRZBuilder.td1(state: "NOR", doc: "JG1234567", dob: "850715", sex: "F", exp: "310101",
                                nat: "NOR", surname: "NORDMANN", given: "KARI")))
        docs.append(Doc("id-nld-front", .idCard, "NL")
            .t("KONINKRIJK DER NEDERLANDEN", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("IDENTITEITSKAART / IDENTITY CARD", 0.33, 0.11, 24)
            .portrait(left)
            .field("Naam / Surname", "DE VRIES", 0.33, 0.20)
            .field("Voornamen / Given names", "ANNA", 0.33, 0.33)
            .field("Geboortedatum / Date of birth", "10 03 1990", 0.33, 0.46)
            .field("Documentnummer / Document no.", "SPECI2021", 0.66, 0.46, .hide(.documentNumber))
            .field("Persoonsnummer / Personal no.", "1112.22.333", 0.33, 0.60, .hide(.personalNumber)))
        docs.append(Doc("id-nld-back", .idCard, "NL")
            .t("KONINKRIJK DER NEDERLANDEN", 0.05, 0.08, 26)
            .mrz(MRZBuilder.td1(state: "NLD", doc: "SPECI2021", optional: "111222333", dob: "900310", sex: "F", exp: "310101",
                                nat: "NLD", surname: "DE<VRIES", given: "ANNA")))
        docs.append(Doc("id-deu-front", .idCard, "DE")
            .t("BUNDESREPUBLIK DEUTSCHLAND", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("PERSONALAUSWEIS", 0.33, 0.11, 24)
            .t("L01X00T47", 0.75, 0.05, 30, .hide(.documentNumber), font: "Helvetica-Bold")
            .portrait(left)
            .field("Name / Surname", "MUSTERMANN", 0.33, 0.20)
            .field("Vornamen / Given names", "ERIKA", 0.33, 0.33)
            .field("Geburtstag / Date of birth", "12.08.1983", 0.33, 0.46)
            .field("Gültig bis / Date of expiry", "01.08.2031", 0.33, 0.59)
            .t("123456", 0.82, 0.88, 34, .hide(.cardAccessNumber), font: "Helvetica-Bold"))
        docs.append(Doc("id-deu-back", .idCard, "DE")
            .t("Anschrift / Address", 0.05, 0.08, 21)
            .t("HEIDESTRASSE 17, 51147 KÖLN", 0.05, 0.13, 30, .hide(.address), font: "Helvetica-Bold")
            .mrz(MRZBuilder.td1(code: "ID", state: "D<<", doc: "L01X00T47", dob: "830812", sex: "F", exp: "310801",
                                nat: "D<<", surname: "MUSTERMANN", given: "ERIKA")))
        docs.append(Doc("id-bel-front", .idCard, "BE")
            .t("BELGIE BELGIQUE BELGIEN", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("IDENTITEITSKAART / CARTE D'IDENTITE", 0.33, 0.11, 24)
            .portrait(left)
            .field("Naam / Nom", "PEETERS", 0.33, 0.20)
            .field("Voornamen / Prénoms", "LUC", 0.33, 0.33)
            .field("Rijksregisternr. / N° national", rrn, 0.33, 0.46, .hide(.personalNumber)))
        docs.append(Doc("id-ita-front", .idCard, "IT")
            .t("REPUBBLICA ITALIANA", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("CARTA DI IDENTITA", 0.33, 0.11, 24)
            .portrait(left)
            .field("COGNOME / SURNAME", "ROSSI", 0.33, 0.20)
            .field("NOME / NAME", "MARIO", 0.33, 0.33)
            .field("CODICE FISCALE / FISCAL CODE", "RSSMRA85T10A562S", 0.33, 0.46, .hide(.personalNumber)))
        docs.append(Doc("id-esp-front", .idCard, "ES")
            .t("REINO DE ESPAÑA", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("DOCUMENTO NACIONAL DE IDENTIDAD", 0.33, 0.11, 24)
            .portrait(left)
            .field("APELLIDOS", "ESPAÑOLA ESPAÑOLA", 0.33, 0.20)
            .field("NOMBRE", "CARMEN", 0.33, 0.33)
            .field("DNI", "12345678Z", 0.33, 0.46, .hide(.personalNumber)))
        docs.append(Doc("id-pol-front", .idCard, "PL")
            .t("RZECZPOSPOLITA POLSKA", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("DOWÓD OSOBISTY", 0.33, 0.11, 24)
            .portrait(left)
            .field("NAZWISKO / SURNAME", "KOWALSKA", 0.33, 0.20)
            .field("IMIONA / GIVEN NAMES", "ANNA", 0.33, 0.33)
            .field("NUMER PESEL", "44051401359", 0.33, 0.46, .hide(.personalNumber)))
        docs.append(Doc("id-swe-front", .idCard, "SE")
            .t("SVERIGE", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("IDENTITETSKORT / IDENTITY CARD", 0.33, 0.11, 24)
            .portrait(left)
            .field("Efternamn / Surname", "SVENSSON", 0.33, 0.20)
            .field("Förnamn / Given names", "LARS", 0.33, 0.33)
            .field("Personnummer / Personal ID no.", "19811218-9876", 0.33, 0.46, .hide(.personalNumber)))
        docs.append(Doc("rp-nor-front", .residencePermit, "NO")
            .t("NORGE NOREG NORWAY", 0.33, 0.05, 30, .plain, font: "Helvetica-Bold")
            .t("OPPHOLDSKORT / RESIDENCE PERMIT", 0.33, 0.11, 24)
            .portrait(left)
            .field("Etternavn / Surname", "SMITH", 0.33, 0.20)
            .field("Fornavn / Given names", "ALEX", 0.33, 0.33)
            .field("Fødselsnummer / Personal No.", fnr, 0.33, 0.46, .hide(.personalNumber))
            .field("Kortnummer / Card No.", "RP1234567", 0.66, 0.46, .hide(.documentNumber)))

        // The German residence permit: the number in the heading (no label), a replacement passport's
        // number in the remarks with its expiry after it.
        docs.append(Doc("rp-deu-front", .residencePermit, "DE")
            .t("BUNDESREPUBLIK DEUTSCHLAND", 0.33, 0.04, 22, .plain, font: "Helvetica-Bold")
            .t("AUFENTHALTSTITEL", 0.33, 0.10, 26)
            .t("L01XPVM8J", 0.72, 0.04, 30, .hide(.documentNumber), font: "Menlo")
            .portrait(left)
            .field("NAMEN / SURNAMES", "MUSTERMANN", 0.33, 0.20)
            .field("ANMERKUNGEN / REMARKS", "ARTIKEL 50 EUV", 0.33, 0.36)
            .t("PASS(ERSATZ) |C56WT9849", 0.33, 0.52, 26, .hide(.documentNumber), font: "Menlo")
            .t("BIS 31 10 2024", 0.66, 0.52, 26, .keep, font: "Menlo"))
        // The French residence permit prints its number, which has few digits, twice.
        docs.append(Doc("rp-fra-front", .residencePermit, "FR")
            .t("RÉPUBLIQUE FRANÇAISE", 0.33, 0.04, 22, .plain, font: "Helvetica-Bold")
            .t("TITRE DE SÉJOUR", 0.33, 0.10, 26)
            .t("3MBMONSFJ", 0.72, 0.04, 30, .hide(.documentNumber), font: "Menlo")
            .t("3MBMONSFJ", 0.03, 0.15, 22, .hide(.documentNumber), font: "Menlo")
            .portrait(CGRect(x: 0.03, y: 0.24, width: 0.27, height: 0.6))
            .field("NOMS / SURNAMES", "TRAORE", 0.33, 0.22)
            .field("NATIONALITÉ / NATIONALITY", "SEN", 0.33, 0.38)
            .field("VALABLE JUSQU'AU / VALID UNTIL", "17/09/2030", 0.60, 0.38))

        // MARK: Asian identity cards
        docs.append(Doc("id-chn-front", .idCard, "CN", tint: (0.96, 0.95, 0.92))
            .t("中华人民共和国 居民身份证", 0.08, 0.04, 34, .plain, font: "Helvetica-Bold")
            .t("姓名  张伟", 0.08, 0.16, 34)
            .t("性别  男    民族  汉", 0.08, 0.27, 34)
            .t("出生  1949 年 12 月 31 日", 0.08, 0.38, 34)
            .t("住址  |北京市朝阳区建国路", 0.08, 0.50, 34, .hide(.address))
            .t("88号院3号楼1201", 0.17, 0.60, 34, .hide(.address))
            .t("公民身份号码  |11010519491231002X", 0.08, 0.80, 36, .hide(.personalNumber))
            .portrait(CGRect(x: 0.68, y: 0.15, width: 0.27, height: 0.55)))
        docs.append(Doc("id-hkg-front", .idCard, "HK")
            .t("香港永久性居民身份證", 0.05, 0.05, 32, .plain, font: "Helvetica-Bold")
            .t("HONG KONG PERMANENT IDENTITY CARD", 0.05, 0.12, 26)
            .t("陳大文", 0.05, 0.24, 34)
            .t("CHAN, Tai Man", 0.05, 0.33, 32, .keep)
            .t("01-01-1990", 0.05, 0.50, 30)
            .t("A123456(3)", 0.05, 0.82, 40, .hide(.personalNumber), font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.66, y: 0.24, width: 0.28, height: 0.6)))
        docs.append(Doc("id-twn-front", .idCard, "TW")
            .t("中華民國國民身分證", 0.05, 0.05, 34, .plain, font: "Helvetica-Bold")
            .t("姓名  陳小明", 0.05, 0.20, 34)
            .t("出生  民國79年1月1日", 0.05, 0.32, 34)
            .t("統一編號  |A123456789", 0.05, 0.80, 36, .hide(.personalNumber))
            .portrait(CGRect(x: 0.66, y: 0.2, width: 0.28, height: 0.6)))
        docs.append(Doc("id-kor-front", .idCard, "KR")
            .t("주민등록증", 0.05, 0.05, 40, .plain, font: "Helvetica-Bold")
            .t("홍길동 (洪吉童)", 0.05, 0.22, 36)
            .t("850101-2345678", 0.05, 0.34, 36, .hide(.personalNumber))
            .t("주소  |서울특별시 종로구 세종대로 209", 0.05, 0.50, 32, .hide(.address))
            .t("2020. 1. 1.  서울특별시 종로구청장", 0.05, 0.82, 26)
            .portrait(CGRect(x: 0.68, y: 0.2, width: 0.27, height: 0.55)))
        docs.append(Doc("id-sgp-front", .idCard, "SG", tint: (0.95, 0.93, 0.93))
            .t("REPUBLIC OF SINGAPORE", 0.05, 0.05, 32, .plain, font: "Helvetica-Bold")
            .t("IDENTITY CARD NO.  |S1234567D", 0.05, 0.14, 32, .hide(.personalNumber))
            .field("Name", "TAN MEI LING", 0.36, 0.30)
            .field("Date of birth", "15-07-1985", 0.36, 0.45)
            .field("Country of birth", "SINGAPORE", 0.36, 0.60)
            .portrait(CGRect(x: 0.05, y: 0.28, width: 0.26, height: 0.6)))
        docs.append(Doc("id-mys-front", .idCard, "MY", tint: (0.93, 0.95, 0.97))
            .t("MALAYSIA", 0.05, 0.04, 32, .plain, font: "Helvetica-Bold")
            .t("KAD PENGENALAN  MyKad", 0.05, 0.11, 26)
            .t("880415-14-5567", 0.05, 0.22, 40, .hide(.personalNumber), font: "Helvetica-Bold")
            .t("NUR AISYAH BINTI AHMAD", 0.05, 0.60, 32, .keep)
            .t("NO 12 JALAN BUNGA RAYA", 0.05, 0.70, 30, .hide(.address))
            .t("50450 KUALA LUMPUR", 0.05, 0.78, 30, .hide(.address))
            .portrait(CGRect(x: 0.66, y: 0.2, width: 0.28, height: 0.6)))
        docs.append(Doc("rp-jpn-front", .residencePermit, "JP")
            .t("在留カード  RESIDENCE CARD", 0.05, 0.05, 32, .plain, font: "Helvetica-Bold")
            .t("番号 |AB12345678CD", 0.62, 0.05, 30, .hide(.documentNumber))
            .t("氏名  SMITH JOHN", 0.05, 0.18, 32, .keep)
            .t("住居地  |東京都千代田区千代田1-1", 0.05, 0.42, 30, .hide(.address))
            .portrait(CGRect(x: 0.70, y: 0.2, width: 0.25, height: 0.55)))

        // MARK: Driving licences, EU model and ISO 18013
        func euLicence(_ name: String, _ country: String, title: String, surname: String, given: String, birth: String,
                       authority: String, personal: String?, number: String, address: String? = nil) -> Doc {
            let d = Doc(name, .drivingLicence, country, tint: (0.96, 0.92, 0.94))
                .t(title, 0.32, 0.04, 30, .plain, font: "Helvetica-Bold")
                .portrait(CGRect(x: 0.03, y: 0.2, width: 0.25, height: 0.62), .hide(.photo))
                .t("1. " + surname, 0.32, 0.18, 30, .keep)
                .t("2. " + given, 0.32, 0.26, 30, .keep)
                .t("3. " + birth, 0.32, 0.34, 30)
                .t("4a. 01.01.2020", 0.32, 0.42, 28)
                .t("4c. " + authority, 0.62, 0.42, 28)
                .t("4b. 01.01.2030", 0.32, 0.50, 28)
            if let personal { d.t("4d. ", 0.62, 0.50, 28).t(personal, 0.68, 0.50, 28, .hide(.personalNumber)) }
            d.t("5. ", 0.32, 0.58, 28).t(number, 0.37, 0.58, 28, .hide(.documentNumber))
            if let address { d.t("8. ", 0.32, 0.66, 28).t(address, 0.37, 0.66, 28, .hide(.address)) }
            d.t("9. AM/B", 0.32, 0.80, 28)
            return d
        }
        let dutchLicenceNumber = "5123456789"
        let dutchLicenceMRZ = "D1NLD3" + dutchLicenceNumber + "ABC12345K789X"
        docs.append(euLicence("dl-nld", "NL", title: "RIJBEWIJS  NEDERLAND", surname: "DE VRIES", given: "ANNA", birth: "10.03.1990 AMSTERDAM",
                              authority: "Burg. Amsterdam", personal: "111222333", number: dutchLicenceNumber)
            .portrait(CGRect(x: 0.71, y: 0.66, width: 0.09, height: 0.15), .hide(.photo))
            .portrait(CGRect(x: 0.84, y: 0.66, width: 0.07, height: 0.15), .hide(.photo))
            .t(dutchLicenceMRZ + MRZBuilder.cd(dutchLicenceMRZ), 0.04, 0.94, 42, .hide(.machineReadableZone), font: "Menlo"))
        docs.append(euLicence("dl-nor", "NO", title: "FØRERKORT  NORGE", surname: "NORDMANN", given: "KARI", birth: "15.07.1985 OSLO",
                              authority: "Statens vegvesen", personal: fnr, number: "10 12345 67 8"))
        docs.append(euLicence("dl-fra", "FR", title: "PERMIS DE CONDUIRE  RÉPUBLIQUE FRANÇAISE", surname: "MARTIN", given: "CLAIRE",
                              birth: "02.05.1988 LYON", authority: "Préfet du Rhône", personal: nil, number: "12AB34567"))
        docs.append(euLicence("dl-gbr", "GB", title: "DRIVING LICENCE  UNITED KINGDOM", surname: "MORGAN", given: "SARAH MS",
                              birth: "05.07.1985 UNITED KINGDOM", authority: "DVLA", personal: nil, number: "MORGA857055SM9IJ 35",
                              address: "12 HIGH STREET, LONDON, SW1A 1AA"))
        // The 2021 card: the address on three lines, town and postcode below the street, with no "8." read.
        docs.append(Doc("dl-gbr-2021", .drivingLicence, "GB", tint: (0.95, 0.93, 0.97))
            .t("UK DRIVING LICENCE", 0.32, 0.04, 30, .plain, font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.03, y: 0.2, width: 0.25, height: 0.5), .hide(.photo))
            .t("1. MORGAN", 0.32, 0.16, 28, .keep)
            .t("2. SARAH", 0.32, 0.23, 28, .keep)
            .t("3. 11.03.1976 UNITED KINGDOM", 0.32, 0.30, 28)
            .t("4a. 06.12.2021  4c. DVLA", 0.32, 0.37, 28)
            .t("4b. 05.12.2031", 0.32, 0.44, 28)
            .t("5. ", 0.32, 0.51, 28).t("MORGA753116SM9IJ 35", 0.37, 0.51, 28, .hide(.documentNumber))
            .t("24 HIGH STREET", 0.37, 0.62, 28, .hide(.address))
            .t("EDINBURGH", 0.37, 0.69, 28, .hide(.address))
            .t("EH1 9GP", 0.37, 0.76, 28, .hide(.address))
            .t("9. AM/A/B1/B", 0.32, 0.88, 28))
        docs.append(Doc("dl-nzl", .drivingLicence, "NZ", tint: (0.95, 0.96, 0.92))
            .t("NEW ZEALAND DRIVER LICENCE", 0.32, 0.04, 30, .plain, font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.03, y: 0.2, width: 0.25, height: 0.62), .hide(.photo))
            .t("1. SMITH", 0.32, 0.18, 30, .keep)
            .t("2. JOHN", 0.32, 0.26, 30, .keep)
            .t("3. 01-01-1990", 0.32, 0.34, 30)
            .t("4a. 01/01/2020", 0.32, 0.42, 28)
            .t("4b. 01/01/2030", 0.32, 0.50, 28)
            .t("5a. |AB123456", 0.32, 0.58, 28, .hide(.documentNumber))
            .t("5b. |123", 0.62, 0.58, 28, .hide(.documentNumber))
            .t("9. 6 B", 0.32, 0.80, 28))

        // MARK: Driving licences, North America (AAMVA)
        docs.append(Doc("dl-usa-front", .drivingLicence, "US", tint: (0.93, 0.95, 0.97))
            .t("CALIFORNIA", 0.04, 0.04, 40, .plain, font: "Helvetica-Bold")
            .t("DRIVER LICENSE  USA", 0.45, 0.06, 28)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .t("4d DLN", 0.36, 0.20, 22).t("D1234567", 0.46, 0.19, 34, .hide(.documentNumber), font: "Helvetica-Bold")
            .t("4b EXP 08/31/2030", 0.36, 0.28, 28)
            .t("1 DOE", 0.36, 0.36, 30, .keep)
            .t("2 JANE", 0.36, 0.43, 30, .keep)
            .t("8 |1234 MAIN ST", 0.36, 0.51, 28, .hide(.address))
            .t("SACRAMENTO, CA 95814", 0.39, 0.58, 28, .hide(.address))
            .t("3 DOB 08/31/1985", 0.36, 0.67, 28)
            .t("5 DD |12345678901234", 0.36, 0.86, 22, .hide(.documentNumber)))
        let doc = Doc("dl-usa-back", .drivingLicence, "US", tint: (0.95, 0.95, 0.95))
            .t("CALIFORNIA", 0.04, 0.05, 28)
        doc.barcode = (CGRect(x: 0.05, y: 0.25, width: 0.9, height: 0.5),
                       "@\n\u{1e}\rANSI 636014090102DL00410288ZC03290024DLDAQD1234567\nDCSDOE\nDACJANE\nDBB08311985\nDAG1234 MAIN ST\nDAISACRAMENTO\nDAJCA\nDAK958140000\n")
        docs.append(doc)
        docs.append(Doc("dl-can-ont", .drivingLicence, "CA", tint: (0.94, 0.95, 0.96))
            .t("ONTARIO", 0.04, 0.04, 40, .plain, font: "Helvetica-Bold")
            .t("DRIVER'S LICENCE / PERMIS DE CONDUIRE", 0.36, 0.06, 24)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .t("4d NUMBER", 0.36, 0.20, 22).t("D1234-56789-01234", 0.52, 0.19, 32, .hide(.documentNumber), font: "Helvetica-Bold")
            .t("1,2 DOE, JANE", 0.36, 0.32, 30, .keep)
            .t("8 |123 QUEEN ST W", 0.36, 0.42, 28, .hide(.address))
            .t("TORONTO, ON M5H 2N2", 0.39, 0.49, 28, .hide(.address))
            .t("4a ISS 2022/01/01", 0.36, 0.60, 26)
            .t("4b EXP 2027/01/01", 0.36, 0.67, 26)
            .t("3 DOB 1985/07/15", 0.36, 0.74, 26))

        // MARK: Driving licences, Oceania and Asia
        docs.append(Doc("dl-aus-nsw", .drivingLicence, "AU", tint: (0.95, 0.96, 0.93))
            .t("NEW SOUTH WALES", 0.04, 0.04, 34, .plain, font: "Helvetica-Bold")
            .t("DRIVER LICENCE  AUSTRALIA", 0.50, 0.06, 26)
            .t("JOHN CITIZEN", 0.04, 0.20, 34, .keep)
            .t("12 GEORGE ST", 0.04, 0.30, 30, .hide(.address))
            .t("SYDNEY NSW 2000", 0.04, 0.37, 30, .hide(.address))
            .field("Licence No.", "12345678", 0.04, 0.50, .hide(.documentNumber))
            .field("Date of Birth", "15 JUL 1985", 0.30, 0.50)
            .field("Card Number", "2012345678", 0.04, 0.70, .hide(.documentNumber))
            .portrait(CGRect(x: 0.68, y: 0.2, width: 0.27, height: 0.6)))
        docs.append(Doc("dl-chn", .drivingLicence, "CN", tint: (0.94, 0.94, 0.96))
            .t("中华人民共和国机动车驾驶证", 0.10, 0.04, 34, .plain, font: "Helvetica-Bold")
            .t("证号  |11010519491231002X", 0.05, 0.16, 32, .hide(.personalNumber))
            .t("姓名  张伟    性别  男", 0.05, 0.28, 32)
            .t("住址  |北京市朝阳区建国路88号", 0.05, 0.40, 32, .hide(.address))
            .t("出生日期  1949-12-31", 0.05, 0.54, 32)
            .t("准驾车型  C1", 0.05, 0.66, 32)
            .portrait(CGRect(x: 0.70, y: 0.25, width: 0.25, height: 0.55)))
        docs.append(Doc("dl-jpn", .drivingLicence, "JP", tint: (0.94, 0.96, 0.94))
            .t("氏名  山田 花子     昭和60年7月15日生", 0.04, 0.06, 32)
            .t("住所  |東京都千代田区霞が関2-1-2", 0.04, 0.18, 32, .hide(.address))
            .t("交付  令和4年1月1日", 0.04, 0.30, 28)
            .t("番号  第 |123456789012 号", 0.04, 0.70, 32, .hide(.documentNumber))
            .t("運転免許証", 0.04, 0.85, 40, .plain, font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.70, y: 0.30, width: 0.25, height: 0.55)))
        docs.append(Doc("dl-kor", .drivingLicence, "KR", tint: (0.94, 0.95, 0.97))
            .t("자동차운전면허증", 0.32, 0.04, 40, .plain, font: "Helvetica-Bold")
            .t("11-12-345678-90", 0.32, 0.18, 36, .hide(.documentNumber))
            .t("홍길동", 0.32, 0.30, 34, .keep)
            .t("850101-2345678", 0.32, 0.40, 32, .hide(.personalNumber))
            .t("주소  |서울특별시 종로구 세종대로 209", 0.32, 0.52, 28, .hide(.address))
            .portrait(CGRect(x: 0.03, y: 0.2, width: 0.25, height: 0.6)))
        docs.append(Doc("dl-sgp", .drivingLicence, "SG", tint: (0.95, 0.95, 0.93))
            .t("SINGAPORE DRIVING LICENCE", 0.32, 0.05, 32, .plain, font: "Helvetica-Bold")
            .field("Name", "TAN MEI LING", 0.32, 0.20)
            .field("Licence No.", "S1234567D", 0.32, 0.36, .hide(.personalNumber))
            .field("Date of Birth", "15-07-1985", 0.32, 0.52)
            .portrait(CGRect(x: 0.03, y: 0.2, width: 0.25, height: 0.6)))
        docs.append(Doc("dl-mys", .drivingLicence, "MY", tint: (0.93, 0.95, 0.96))
            .t("LESEN MEMANDU MALAYSIA", 0.32, 0.05, 32, .plain, font: "Helvetica-Bold")
            .field("Nama / Name", "NUR AISYAH BINTI AHMAD", 0.32, 0.20)
            .field("No. Pengenalan / Identity No.", "880415-14-5567", 0.32, 0.36, .hide(.personalNumber))
            .field("Alamat / Address", "NO 12 JALAN BUNGA RAYA, 50450 KUALA LUMPUR", 0.32, 0.52, .hide(.address))
            .portrait(CGRect(x: 0.03, y: 0.2, width: 0.25, height: 0.6)))

        // MARK: United States: green card, passport card, state ID
        docs.append(Doc("rp-usa-front", .residencePermit, "US", tint: (0.93, 0.96, 0.93))
            .t("UNITED STATES OF AMERICA", 0.04, 0.04, 30, .plain, font: "Helvetica-Bold")
            .t("PERMANENT RESIDENT", 0.58, 0.05, 32, .plain, font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.04, y: 0.22, width: 0.27, height: 0.6))
            .field("Surname", "SPECIMEN", 0.38, 0.16)
            .field("Given Name", "TEST V", 0.38, 0.28)
            .field("USCIS#", "000-000-001", 0.38, 0.40, .hide(.personalNumber))
            .field("Category", "IR1", 0.66, 0.40)
            .field("Country of Birth", "CANADA", 0.38, 0.52)
            .field("Date of Birth        Sex", "17 AUG 1958     F", 0.38, 0.64)
            .field("Card Expires:", "04/02/2034", 0.38, 0.78))
        docs.append(Doc("id-usa-passcard", .idCard, "US", tint: (0.94, 0.95, 0.97))
            .t("UNITED STATES OF AMERICA", 0.36, 0.04, 30, .plain, font: "Helvetica-Bold")
            .t("PASSPORT CARD", 0.36, 0.11, 26)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .field("Surname", "TRAVELER", 0.36, 0.20)
            .field("Given Names", "HAPPY", 0.36, 0.32)
            .field("Passport Card no.", "C03005988", 0.66, 0.20, .hide(.documentNumber))
            .field("Date of Birth", "04 JUL 1967", 0.36, 0.44)
            .field("Expires On", "07 AUG 2034", 0.36, 0.56))
        docs.append(Doc("id-usa-ny", .idCard, "US", tint: (0.95, 0.95, 0.97))
            .t("NEW YORK STATE", 0.04, 0.04, 38, .plain, font: "Helvetica-Bold")
            .t("IDENTIFICATION CARD", 0.50, 0.06, 26)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .t("ID NO. |123 456 789", 0.36, 0.20, 30, .hide(.documentNumber))
            .t("DOE, JANE", 0.36, 0.32, 30, .keep)
            .t("123 MAIN ST", 0.36, 0.41, 28, .hide(.address))
            .t("ALBANY, NY 12207", 0.36, 0.48, 28, .hide(.address))
            .t("DOB |08/31/1985", 0.36, 0.60, 28, .keep)
            .t("EXPIRES |08/31/2032", 0.36, 0.69, 28, .keep))

        // MARK: United States and Canada: more cards (made-up numbers with valid checks; CMS's example Medicare number)
        docs.append(Doc("rp-usa-ead", .residencePermit, "US", tint: (0.95, 0.94, 0.96))
            .t("UNITED STATES OF AMERICA", 0.04, 0.04, 30, .plain, font: "Helvetica-Bold")
            .t("EMPLOYMENT AUTHORIZATION", 0.52, 0.05, 28, .plain, font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.04, y: 0.22, width: 0.27, height: 0.6))
            .field("Surname", "SPECIMEN", 0.38, 0.16)
            .field("Given Name", "TEST V", 0.38, 0.28)
            .field("USCIS#", "000-000-001", 0.38, 0.40, .hide(.personalNumber))
            .field("Category", "C09", 0.70, 0.40)
            .field("Card#", "SRC0123456789", 0.38, 0.52, .hide(.documentNumber))
            .field("Valid From:", "01/01/2026", 0.38, 0.66)
            .field("Card Expires:", "01/01/2031", 0.66, 0.66, .keep))
        docs.append(Doc("id-usa-medicare", .idCard, "US", tint: (0.96, 0.96, 0.98))
            .t("MEDICARE HEALTH INSURANCE", 0.05, 0.06, 34, .plain, font: "Helvetica-Bold")
            .field("Name/Nombre", "JOHN L SMITH", 0.05, 0.24)
            .field("Medicare Number/Número de Medicare", "1EG4-TE5-MK73", 0.05, 0.44, .hide(.personalNumber))
            .field("Entitled to", "HOSPITAL (PART A)", 0.05, 0.64)
            .field("Coverage starts", "03-01-2016", 0.55, 0.64))
        docs.append(Doc("dl-can-qc", .drivingLicence, "CA", tint: (0.94, 0.95, 0.97))
            .t("QUÉBEC", 0.04, 0.04, 40, .plain, font: "Helvetica-Bold")
            .t("PERMIS DE CONDUIRE", 0.40, 0.06, 28)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .field("Numéro de référence", "T6512-150785-01", 0.36, 0.15, .hide(.documentNumber))
            .t("TREMBLAY", 0.36, 0.30, 30, .keep)
            .t("MARIE", 0.36, 0.37, 30, .keep)
            .t("1234 RUE SAINT-DENIS", 0.36, 0.47, 28, .hide(.address))
            .t("MONTRÉAL QC H2X 3K2", 0.36, 0.54, 28, .hide(.address))
            .t("Date de naissance 1985-07-15", 0.36, 0.65, 24)
            .t("Expire le 2030-07-15", 0.36, 0.73, 24))
        docs.append(Doc("rp-can", .residencePermit, "CA", tint: (0.95, 0.95, 0.93))
            .t("GOVERNMENT OF CANADA / GOUVERNEMENT DU CANADA", 0.04, 0.04, 22, .plain, font: "Helvetica-Bold")
            .t("PERMANENT RESIDENT CARD / CARTE DE RÉSIDENT PERMANENT", 0.04, 0.10, 20)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .field("Name / Nom", "SPECIMEN, JANE", 0.36, 0.20)
            .field("ID No / N° ID", "1234-5678", 0.36, 0.34, .hide(.personalNumber))
            .field("Nationality / Nationalité", "FRA", 0.66, 0.34)
            .field("Date of birth / Date de naissance", "15 JUL / JUIL 1985", 0.36, 0.48)
            .field("Expiry / Expiration", "15 JUL / JUIL 2030", 0.36, 0.62, .keep))
        docs.append(Doc("id-can-ont-health", .idCard, "CA", tint: (0.93, 0.96, 0.93))
            .t("ONTARIO", 0.36, 0.04, 40, .plain, font: "Helvetica-Bold")
            .t("HEALTH + SANTÉ", 0.66, 0.06, 28)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .t("DOE, JANE", 0.36, 0.22, 32, .keep)
            .t("1234 - 567 - 897 - AB", 0.36, 0.36, 36, .hide(.personalNumber), font: "Helvetica-Bold")
            .t("BORN/NÉ(E) 1985-07-15", 0.36, 0.52, 24)
            .t("EXP/EXP 2030-07-15", 0.36, 0.60, 24, .keep))
        docs.append(Doc("id-can-bc", .idCard, "CA", tint: (0.93, 0.95, 0.97))
            .t("BRITISH COLUMBIA", 0.04, 0.04, 36, .plain, font: "Helvetica-Bold")
            .t("SERVICES CARD", 0.55, 0.06, 28)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .t("DOE, JANE", 0.36, 0.22, 32, .keep)
            .field("Personal Health Number", "9698 658 215", 0.36, 0.36, .hide(.personalNumber))
            .field("Expiry", "2030-JUL-15", 0.36, 0.56, .keep))

        // MARK: Saudi Arabia (made-up numbers with valid Luhn digits; Hijri dates)
        docs.append(passport("passport-sau", "SAU", "SA", title: "المملكة العربية السعودية  KINGDOM OF SAUDI ARABIA  PASSPORT",
                             surname: "ALQAHTANI", given: "SARA", doc: "R1234567"))
        docs.append(Doc("id-sau-front", .idCard, "SA", tint: (0.93, 0.96, 0.94))
            .ar("المملكة العربية السعودية", 0.96, 0.04, 32, bold: true)
            .t("KINGDOM OF SAUDI ARABIA", 0.36, 0.05, 26, .plain, font: "Helvetica-Bold")
            .ar("بطاقة الهوية الوطنية", 0.96, 0.13, 28)
            .t("NATIONAL IDENTITY CARD", 0.36, 0.14, 22)
            .portrait(CGRect(x: 0.04, y: 0.22, width: 0.27, height: 0.6))
            .ar("سارة محمد القحطاني", 0.96, 0.27, 32, .keep, bold: true)
            .t("SARA MOHAMMED ALQAHTANI", 0.36, 0.37, 28, .keep)
            .ar("رقم الهوية |١٠١٢٣٤٥٦٧٢", 0.96, 0.49, 32, .hide(.personalNumber))
            .ar("تاريخ الميلاد |1405/03/12", 0.96, 0.62, 28, .keep)
            .ar("تاريخ الانتهاء |1450/01/01", 0.96, 0.74, 28, .keep))
        docs.append(Doc("rp-sau-front", .residencePermit, "SA", tint: (0.94, 0.95, 0.97))
            .ar("المملكة العربية السعودية - وزارة الداخلية", 0.96, 0.04, 28, bold: true)
            .t("KINGDOM OF SAUDI ARABIA", 0.04, 0.05, 24, .plain, font: "Helvetica-Bold")
            .ar("هوية مقيم", 0.96, 0.13, 30, bold: true)
            .t("RESIDENT IDENTITY", 0.04, 0.14, 24)
            .portrait(CGRect(x: 0.04, y: 0.25, width: 0.25, height: 0.58))
            .t("ID No. |2123456788", 0.34, 0.27, 30, .hide(.personalNumber))
            .ar("رقم الهوية", 0.96, 0.27, 28)
            .t("JOHN SMITH", 0.34, 0.39, 30, .keep)
            .ar("جون سميث", 0.96, 0.39, 30, .keep)
            .t("Nationality |EGYPT", 0.34, 0.51, 26)
            .ar("الجنسية |مصر", 0.96, 0.51, 26)
            .t("Employer |ABC TRADING CO", 0.34, 0.63, 26)
            .ar("صاحب العمل", 0.96, 0.63, 26)
            .t("Expiry |1450/01/01", 0.34, 0.75, 26, .keep))
        docs.append(Doc("dl-sau", .drivingLicence, "SA", tint: (0.95, 0.95, 0.93))
            .ar("المملكة العربية السعودية", 0.96, 0.04, 30, bold: true)
            .ar("رخصة قيادة", 0.96, 0.12, 30, bold: true)
            .t("DRIVING LICENSE", 0.36, 0.06, 28, .plain, font: "Helvetica-Bold")
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .ar("رقم الهوية |1012345672", 0.96, 0.28, 30, .hide(.personalNumber))
            .t("Name |SARA ALQAHTANI", 0.36, 0.40, 28, .keep)
            .t("Blood Type  O+", 0.36, 0.52, 26)
            .ar("تاريخ الانتهاء |1450/01/01", 0.96, 0.64, 28, .keep))

        // MARK: United Arab Emirates (made-up Emirates ID number with a valid Luhn digit)
        let emiratesID = "784-1990-1234567-6"
        docs.append(passport("passport-are", "ARE", "AE", title: "دولة الإمارات العربية المتحدة  UNITED ARAB EMIRATES  PASSPORT",
                             surname: "ALMANSOORI", given: "FATIMA", doc: "N1234567"))
        docs.append(Doc("id-are-front", .idCard, "AE", tint: (0.95, 0.94, 0.92))
            .ar("دولة الإمارات العربية المتحدة", 0.96, 0.04, 30, bold: true)
            .t("UNITED ARAB EMIRATES", 0.04, 0.05, 28, .plain, font: "Helvetica-Bold")
            .ar("بطاقة الهوية", 0.96, 0.13, 28)
            .t("IDENTITY CARD", 0.04, 0.14, 24)
            .t("ID Number |" + emiratesID, 0.36, 0.25, 30, .hide(.personalNumber))
            .ar("رقم الهوية", 0.96, 0.25, 28)
            .t("Name: FATIMA ALI ALMANSOORI", 0.36, 0.38, 28, .keep)
            .ar("الاسم: فاطمة علي المنصوري", 0.96, 0.48, 28, .keep)
            .t("Date of Birth: 15/07/1990", 0.36, 0.60, 24)
            .t("Expiry Date: |01/01/2030", 0.36, 0.70, 24, .keep)
            .portrait(CGRect(x: 0.04, y: 0.25, width: 0.27, height: 0.6)))
        docs.append(Doc("id-are-back", .idCard, "AE", tint: (0.95, 0.94, 0.92))
            .t("Card Number |123456789", 0.04, 0.08, 28, .hide(.documentNumber))
            .t("Occupation: ENGINEER", 0.04, 0.20, 26)
            .t("Issuing Place: DUBAI", 0.04, 0.30, 26)
            .mrz(MRZBuilder.td1(code: "IL", state: "ARE", doc: "123456789", optional: "784199012345676", dob: "900715", sex: "F",
                                exp: "300101", nat: "ARE", surname: "ALMANSOORI", given: "FATIMA ALI")))
        docs.append(Doc("rp-are-front", .residencePermit, "AE", tint: (0.94, 0.95, 0.97))
            .ar("دولة الإمارات العربية المتحدة", 0.96, 0.04, 30, bold: true)
            .t("UNITED ARAB EMIRATES", 0.04, 0.05, 28, .plain, font: "Helvetica-Bold")
            .ar("بطاقة هوية مقيم", 0.96, 0.13, 28)
            .t("RESIDENT IDENTITY CARD", 0.04, 0.14, 24)
            .t("ID Number |784-1985-7654321-3", 0.36, 0.25, 30, .hide(.personalNumber))
            .t("Name: JOHN SMITH", 0.36, 0.38, 28, .keep)
            .t("Nationality: United Kingdom", 0.36, 0.50, 24)
            .t("Expiry Date: |01/01/2028", 0.36, 0.62, 24, .keep)
            .portrait(CGRect(x: 0.04, y: 0.25, width: 0.27, height: 0.6)))
        docs.append(Doc("dl-are", .drivingLicence, "AE", tint: (0.93, 0.95, 0.96))
            .t("UNITED ARAB EMIRATES", 0.36, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("DRIVING LICENSE", 0.36, 0.11, 26)
            .ar("رخصة قيادة", 0.96, 0.11, 26, bold: true)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .field("License No.", "1234567", 0.36, 0.20, .hide(.documentNumber))
            .field("Traffic Code No.", "50123456", 0.66, 0.20, .hide(.personalNumber))
            .field("Name", "JOHN SMITH", 0.36, 0.36)
            .field("Nationality", "UNITED KINGDOM", 0.36, 0.52)
            .field("Expiry Date", "01/01/2030", 0.66, 0.52)
            .field("Place of Issue", "DUBAI", 0.36, 0.68))

        // MARK: Egypt (made-up national number with a valid date and governorate)
        let egyptNumber = "٢٩٠٠١٠١٠١٢٣٤٥٦" // 29001010123456
        docs.append(passport("passport-egy", "EGY", "EG", title: "جمهورية مصر العربية  ARAB REPUBLIC OF EGYPT  PASSPORT",
                             surname: "HASSAN", given: "AHMED", doc: "A12345678"))
        docs.append(Doc("id-egy-front", .idCard, "EG", tint: (0.95, 0.94, 0.92))
            .ar("جمهورية مصر العربية", 0.96, 0.04, 30, bold: true)
            .ar("بطاقة تحقيق الشخصية", 0.96, 0.12, 28)
            .portrait(CGRect(x: 0.04, y: 0.18, width: 0.27, height: 0.6))
            .ar("أحمد", 0.96, 0.25, 36, .keep, bold: true)
            .ar("محمد علي حسن", 0.96, 0.35, 34, .keep, bold: true)
            .ar("١٢ شارع التحرير", 0.96, 0.47, 32, .hide(.address))
            .ar("الدقي - الجيزة", 0.96, 0.57, 32, .hide(.address))
            .ar(egyptNumber, 0.96, 0.79, 40, .hide(.personalNumber), bold: true)
            .t("IR1234567", 0.06, 0.84, 28, .hide(.documentNumber)))
        docs.append(Doc("id-egy-back", .idCard, "EG", tint: (0.95, 0.94, 0.92))
            .ar(egyptNumber, 0.96, 0.08, 34, .hide(.personalNumber), bold: true)
            .ar("مهندس", 0.96, 0.25, 30, .keep)
            .ar("جهة العمل |شركة النيل", 0.96, 0.37, 28)
            .ar("ذكر", 0.96, 0.50, 28)
            .ar("البطاقة سارية حتى |2030/01/01", 0.96, 0.75, 28, .keep))
        docs.append(Doc("dl-egy", .drivingLicence, "EG", tint: (0.93, 0.95, 0.96))
            .ar("جمهورية مصر العربية", 0.96, 0.04, 28, bold: true)
            .ar("رخصة قيادة خاصة", 0.96, 0.12, 30, bold: true)
            .portrait(CGRect(x: 0.04, y: 0.2, width: 0.27, height: 0.62))
            .ar("الاسم |أحمد محمد علي", 0.96, 0.26, 30, .keep)
            .ar("الرقم القومي |" + egyptNumber, 0.96, 0.38, 30, .hide(.personalNumber))
            .ar("العنوان |١٢ شارع التحرير الدقي", 0.96, 0.50, 28, .hide(.address))
            .ar("وحدة مرور الدقي", 0.96, 0.62, 28)
            .ar("تاريخ الانتهاء |2030/01/01", 0.96, 0.74, 28, .keep))

        // MARK: Payslips (no country printed; made-up numbers with valid checks, BZSt/DRV published examples)
        docs.append(Doc("payslip-gbr", .unknown, "", tint: (0.97, 0.97, 0.97))
            .t("ACME TRADING LTD   PAYSLIP", 0.04, 0.04, 32, .plain, font: "Helvetica-Bold")
            .t("JANE DOE", 0.04, 0.14, 28, .keep)
            .t("12 HIGH STREET", 0.04, 0.21, 26, .hide(.address))
            .t("LONDON SW1A 1AA", 0.04, 0.27, 26, .hide(.address))
            .t("NI Number |AB 12 34 56 C", 0.52, 0.14, 26, .hide(.personalNumber))
            .t("Tax Code |1257L", 0.52, 0.21, 26, .keep)
            .t("Pay Date |28/02/2026", 0.52, 0.28, 26, .keep)
            .t("Gross Pay   £3,250.00", 0.04, 0.45, 28)
            .t("Net Pay |£2,512.40", 0.04, 0.53, 28, .keep)
            .t("Sort Code |12-34-56", 0.04, 0.70, 26, .hide(.personalNumber))
            .t("Account No. |12345678", 0.52, 0.70, 26, .hide(.personalNumber)))
        docs.append(Doc("payslip-deu", .unknown, "", tint: (0.97, 0.97, 0.97))
            .t("Beispiel GmbH   Gehaltsabrechnung Februar 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("Erika Mustermann", 0.04, 0.14, 28, .keep)
            .t("Musterstraße 12a", 0.04, 0.21, 26, .hide(.address))
            .t("10115 Berlin", 0.04, 0.27, 26, .hide(.address))
            .t("Steuer-ID |86095742719", 0.52, 0.14, 26, .hide(.personalNumber))
            .t("SV-Nummer |15 070649 C 103", 0.52, 0.21, 26, .hide(.personalNumber))
            .t("Steuerklasse |1", 0.52, 0.28, 26, .keep)
            .t("Gesamtbrutto   3.250,00 €", 0.04, 0.45, 28)
            .t("Nettoverdienst |2.145,30 €", 0.04, 0.53, 28, .keep)
            .t("IBAN |DE89 3704 0044 0532 0130 00", 0.04, 0.70, 26, .hide(.accountNumber)))
        docs.append(Doc("payslip-nld", .unknown, "", tint: (0.97, 0.97, 0.97))
            .t("Voorbeeld B.V.   Loonstrook februari 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("A. de Vries", 0.04, 0.14, 28, .keep)
            .t("Dorpsstraat 10A", 0.04, 0.21, 26, .hide(.address))
            .t("1234 AB Amsterdam", 0.04, 0.27, 26, .hide(.address))
            .t("BSN/sofinr. |111222333", 0.52, 0.14, 26, .hide(.personalNumber))
            .t("Loonheffingennr. |001234567L01", 0.52, 0.21, 22, .keep)
            .t("KvK |12345678", 0.52, 0.28, 26, .keep)
            .t("Bruto salaris   € 3.250,00", 0.04, 0.45, 28)
            .t("Nettoloon |€ 2.412,15", 0.04, 0.53, 28, .keep)
            .t("IBAN |NL91 ABNA 0417 1643 00", 0.04, 0.70, 26, .hide(.accountNumber)))
        docs.append(Doc("payslip-esp", .unknown, "ES", tint: (0.97, 0.97, 0.97))
            .t("Ejemplo Ibérica S.L.   Nómina febrero 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("María García López", 0.04, 0.14, 28, .keep)
            .t("C/ Mayor, 12, 3º B", 0.04, 0.21, 26, .hide(.address))
            .t("28013 Madrid", 0.04, 0.27, 26, .hide(.address))
            .t("NIF |12345678Z", 0.52, 0.14, 26, .hide(.personalNumber))
            .t("Nº Afiliación |28/12345678/40", 0.52, 0.21, 26, .hide(.personalNumber))
            .t("CIF |B12345674", 0.52, 0.28, 26, .keep)
            .t("C.C.C. |28/1234567/85", 0.52, 0.35, 26, .keep)
            .t("Total devengado   2.450,00 €", 0.04, 0.45, 28)
            .t("Líquido a percibir |1.985,40 €", 0.04, 0.53, 28, .keep)
            .t("IBAN |ES91 2100 0418 4502 0005 1332", 0.04, 0.70, 26, .hide(.accountNumber)))
        docs.append(Doc("payslip-fra", .unknown, "", tint: (0.97, 0.97, 0.97))
            .t("Exemple SAS   Bulletin de paie février 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("Jean Dupont", 0.04, 0.14, 28, .keep)
            .t("12 bis rue de la Paix", 0.04, 0.21, 26, .hide(.address))
            .t("75002 PARIS", 0.04, 0.27, 26, .hide(.address))
            .t("N° SS |1 85 05 75 112 233 44", 0.52, 0.14, 26, .hide(.personalNumber))
            .t("SIRET |732 829 320 00017", 0.52, 0.21, 26, .keep)
            .t("Code APE |6201Z", 0.52, 0.28, 26, .keep)
            .t("Salaire brut   3 250,00 €", 0.04, 0.45, 28)
            .t("Net à payer |2 512,40 €", 0.04, 0.53, 28, .keep)
            .t("IBAN |FR76 3000 6000 0112 3456 7890 189", 0.04, 0.70, 26, .hide(.accountNumber)))
        docs.append(Doc("payslip-dnk", .unknown, "", tint: (0.97, 0.97, 0.97))
            .t("Eksempel ApS   Lønseddel februar 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("Mette Hansen", 0.04, 0.14, 28, .keep)
            .t("Nørregade 12, 2. tv.", 0.04, 0.21, 26, .hide(.address))
            .t("1165 København K", 0.04, 0.27, 26, .hide(.address))
            .t("CPR-nr. |010190-1234", 0.52, 0.14, 26, .hide(.personalNumber))
            .t("CVR-nr. |23456788", 0.52, 0.21, 26, .keep)
            .t("Bruttoløn   32.500,00 kr.", 0.04, 0.45, 28)
            .t("Til udbetaling |21.345,00 kr.", 0.04, 0.53, 28, .keep)
            .t("Reg.nr./konto |1234 0012345678", 0.04, 0.70, 26, .hide(.personalNumber)))
        docs.append(Doc("payslip-ind", .unknown, "IN", tint: (0.97, 0.97, 0.97))
            .t("Example Technologies Pvt Ltd   Payslip February 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("Rahul Sharma", 0.04, 0.13, 28, .keep)
            .t("S/O |Rajesh Sharma, Flat 402, 12th Cross", 0.04, 0.20, 24, .hide(.address))
            .t("Indiranagar, Bengaluru 560038", 0.04, 0.26, 24, .hide(.address))
            .t("PAN |ABCPS1234K", 0.58, 0.13, 26, .hide(.personalNumber))
            .t("UAN |100123456789", 0.58, 0.20, 26, .hide(.personalNumber))
            .t("Employer PAN |AAACE1234F", 0.04, 0.38, 24, .keep)
            .t("TAN |BLRE12345F", 0.58, 0.38, 24, .keep)
            .t("GSTIN |29ABCDE1234F1ZW", 0.04, 0.46, 24, .keep)
            .t("Net Pay |Rs 85,400.00", 0.04, 0.58, 28, .keep)
            .t("Account No. |50100123456789", 0.04, 0.72, 26, .hide(.personalNumber)))
        docs.append(Doc("payslip-chn", .unknown, "CN", tint: (0.97, 0.97, 0.97))
            .t("示例科技有限公司  工资条 2026年2月", 0.04, 0.04, 30, .plain, font: "Helvetica-Bold")
            .t("张伟", 0.04, 0.14, 30, .keep)
            .t("北京市朝阳区建国路88号院3号楼1201", 0.04, 0.22, 28, .hide(.address))
            .t("身份证号 |11010519491231002X", 0.04, 0.32, 28, .hide(.personalNumber))
            .t("统一社会信用代码 |91110108MA0123456G", 0.04, 0.40, 26, .keep)
            .t("应发工资  15,000.00", 0.04, 0.50, 28)
            .t("实发工资 |12,345.00", 0.04, 0.58, 28, .keep)
            .t("银行卡号 |6222 0212 3456 7890 128", 0.04, 0.72, 28, .hide(.personalNumber)))
        docs.append(Doc("payslip-aus", .unknown, "", tint: (0.97, 0.97, 0.97))
            .t("Example Pty Ltd   Payslip February 2026", 0.04, 0.04, 28, .plain, font: "Helvetica-Bold")
            .t("ABN |51 824 753 556", 0.58, 0.13, 26, .keep)
            .t("Jane Citizen", 0.04, 0.13, 28, .keep)
            .t("Unit 3, 12 Smith St", 0.04, 0.20, 26, .hide(.address))
            .t("PARRAMATTA NSW 2150", 0.04, 0.26, 26, .hide(.address))
            .t("TFN |123 456 782", 0.58, 0.20, 26, .hide(.personalNumber))
            .t("Gross Pay   $6,250.00", 0.04, 0.45, 28)
            .t("Net Pay |$4,512.40", 0.04, 0.53, 28, .keep)
            .t("BSB |062-000", 0.04, 0.70, 26, .hide(.personalNumber))
            .t("Account No. |12345678", 0.52, 0.70, 26, .hide(.personalNumber)))
        docs.append(Doc("id-aus-medicare", .idCard, "", tint: (0.90, 0.95, 0.90))
            .t("medicare", 0.05, 0.06, 44, .plain, font: "Helvetica-Bold")
            .t("2987 65434 1", 0.05, 0.36, 40, .hide(.personalNumber))
            .t("JANE CITIZEN", 0.12, 0.56, 32, .keep)
            .t("VALID TO 02/2030", 0.55, 0.80, 28, .keep))

        return docs
    }

    // MARK: Drawing

    /// Margin of table around the document, so finding its edges is part of the test.
    static let margin: CGFloat = 90

    static func render(_ doc: Doc) -> (CGImage, Expected) {
        let w = Int(doc.size.width), h = Int(doc.size.height)
        let m = margin
        let canvasW = CGFloat(w) + 2 * m, canvasH = CGFloat(h) + 2 * m
        let ctx = CGContext(data: nil, width: Int(canvasW), height: Int(canvasH), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        // A dark table, then the document on it with rounded corners.
        ctx.setFillColor(CGColor(srgbRed: 0.22, green: 0.2, blue: 0.19, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
        ctx.translateBy(x: m, y: m)
        let W = CGFloat(w), H = CGFloat(h)
        ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: W, height: H), cornerWidth: H * 0.04, cornerHeight: H * 0.04, transform: nil))
        ctx.clip()
        ctx.setFillColor(CGColor(srgbRed: doc.tint.0, green: doc.tint.1, blue: doc.tint.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        // Faint guilloche, like security printing.
        ctx.setStrokeColor(CGColor(srgbRed: doc.tint.0 - 0.06, green: doc.tint.1 - 0.05, blue: doc.tint.2 - 0.03, alpha: 1))
        ctx.setLineWidth(1.2)
        for k in 0..<14 {
            ctx.beginPath()
            for x in stride(from: 0, through: W, by: 6) {
                let y = H * CGFloat(k) / 14 + 18 * sin(x / 70 + CGFloat(k))
                if x == 0 { ctx.move(to: CGPoint(x: x, y: y)) } else { ctx.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.strokePath()
        }

        var hide: [Expected.Box] = []
        var keep: [Expected.Box] = []
        func record(_ role: Role, _ rect: CGRect, _ text: String) {
            // Expected boxes are measured on the whole photo, table included.
            let n = CGRect(x: (rect.minX + m) / canvasW, y: (rect.minY + m) / canvasH, width: rect.width / canvasW, height: rect.height / canvasH)
            switch role {
            case .plain: break
            case .keep: keep.append(.init(kind: "keep", rect: n, text: text))
            case .hide(let k): hide.append(.init(kind: k.rawValue, rect: n, text: text))
            }
        }

        for (r, role) in doc.photos {
            let px = CGRect(x: r.minX * W, y: r.minY * H, width: r.width * W, height: r.height * H)
            let bl = CGRect(x: px.minX, y: H - px.maxY, width: px.width, height: px.height)
            ctx.setFillColor(CGColor(srgbRed: 0.78, green: 0.79, blue: 0.8, alpha: 1))
            ctx.fill(bl)
            ctx.saveGState()
            ctx.clip(to: bl)
            defer { ctx.restoreGState() }
            ctx.setFillColor(CGColor(srgbRed: 0.6, green: 0.62, blue: 0.64, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: bl.midX - bl.width * 0.2, y: bl.minY + bl.height * 0.45, width: bl.width * 0.4, height: bl.height * 0.36))
            ctx.fillEllipse(in: CGRect(x: bl.midX - bl.width * 0.38, y: bl.minY - bl.height * 0.2, width: bl.width * 0.76, height: bl.height * 0.6))
            record(role, px, "photo")
        }

        if let (r, payload) = doc.barcode {
            let filter = CIFilter(name: "CIPDF417BarcodeGenerator")!
            filter.setValue(payload.data(using: .isoLatin1), forKey: "inputMessage")
            let ci = filter.outputImage!
            let cg = CIContext().createCGImage(ci, from: ci.extent)!
            let px = CGRect(x: r.minX * W, y: r.minY * H, width: r.width * W, height: r.height * H)
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: CGRect(x: px.minX, y: H - px.maxY, width: px.width, height: px.height))
            record(.hide(.barcode), px, "PDF417")
        }

        for (index, (whole, origin, size, fontName, wholeRole)) in doc.items.enumerated() {
            let rtl = doc.rightToLeft.contains(index)
            // "Label|value": the label is drawn as plain text, only the value is expected to be hidden.
            var segments: [(String, Role)] = [(whole, wholeRole)]
            if whole.contains("|") {
                let parts = whole.split(separator: "|", maxSplits: 1).map(String.init)
                segments = [(parts[0], .plain), (parts[1], wholeRole)]
            }
            var x = origin.x * W
            for (segment, role) in segments {
            // Right to left, the label's trailing space separates it from the value on its left.
            let text = rtl ? String(segment.reversed().drop(while: { $0 == " " }).reversed()) : segment
            let font = CTFontCreateWithName(fontName as CFString, size, nil)
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0.1, green: 0.11, blue: 0.13, alpha: 1),
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
            if rtl { x -= width }
            let top = origin.y * H
            ctx.textPosition = CGPoint(x: x, y: H - top - ascent)
            // The ink itself (not the line's typographic box): what a mask has to cover exactly.
            // Measured before drawing, since drawing moves the text position along.
            let ink = CTLineGetImageBounds(line, ctx)
            CTLineDraw(line, ctx)
            // Image bounds come back in the context's space with the text position applied (origin bottom left).
            let inkRect = ink.isNull || ink.width <= 0 ? CGRect(x: x, y: top, width: width, height: ascent + descent)
                : CGRect(x: ink.minX, y: H - ink.maxY, width: ink.width, height: ink.height)
            record(role, inkRect, text)
            if !rtl { x += width } else { x -= CGFloat(segment.count - text.count) * size * 0.28 }
            }
        }

        let expected = Expected(name: doc.name, kind: doc.kind.rawValue, country: doc.country, hide: hide, keep: keep)
        return (ctx.makeImage()!, expected)
    }

    static func write(_ image: CGImage, to url: URL, type: UTType = .png) {
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    static func load(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}
