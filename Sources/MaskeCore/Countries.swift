import Foundation

public enum Region: String, CaseIterable, Sendable {
    case europe, northAmerica, oceania, eastAsia, southeastAsia, other
}

public struct Country: Identifiable, Hashable, Sendable {
    /// ISO 3166-1 alpha-2, e.g. "NO".
    public let code: String
    /// The code used in machine-readable zones (alpha-3, except Germany's "D").
    public let mrzCode: String
    public let region: Region
    public let documents: [DocumentKind]

    public var id: String { code }

    public var flag: String {
        code.unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }.map(String.init).joined()
    }

    /// On the list Maske is tested against. Documents from elsewhere still get the machine-readable
    /// zone and the general rules, with a warning to check carefully.
    public var isSupported: Bool { Countries.supported.contains(code) }

    public func name(locale: Locale = .current) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }
}

public enum Countries {
    private static let euDocs: [DocumentKind] = [.passport, .idCard, .residencePermit, .drivingLicence]
    private static let europeDocs: [DocumentKind] = [.passport, .idCard, .drivingLicence]

    private static func c(_ code: String, _ mrz: String, _ region: Region, _ docs: [DocumentKind]) -> Country {
        Country(code: code, mrzCode: mrz, region: region, documents: docs)
    }

    /// Every country Maske has a profile for. Passports from anywhere still work through the
    /// machine-readable zone; these are the ones whose documents are checked field by field.
    public static let all: [Country] = [
        // European Union
        c("AT", "AUT", .europe, euDocs), c("BE", "BEL", .europe, euDocs), c("BG", "BGR", .europe, euDocs),
        c("HR", "HRV", .europe, euDocs), c("CY", "CYP", .europe, euDocs), c("CZ", "CZE", .europe, euDocs),
        c("DK", "DNK", .europe, euDocs), c("EE", "EST", .europe, euDocs), c("FI", "FIN", .europe, euDocs),
        c("FR", "FRA", .europe, euDocs), c("DE", "D", .europe, euDocs), c("GR", "GRC", .europe, euDocs),
        c("HU", "HUN", .europe, euDocs), c("IE", "IRL", .europe, euDocs), c("IT", "ITA", .europe, euDocs),
        c("LV", "LVA", .europe, euDocs), c("LT", "LTU", .europe, euDocs), c("LU", "LUX", .europe, euDocs),
        c("MT", "MLT", .europe, euDocs), c("NL", "NLD", .europe, euDocs), c("PL", "POL", .europe, euDocs),
        c("PT", "PRT", .europe, euDocs), c("RO", "ROU", .europe, euDocs), c("SK", "SVK", .europe, euDocs),
        c("SI", "SVN", .europe, euDocs), c("ES", "ESP", .europe, euDocs), c("SE", "SWE", .europe, euDocs),
        // EEA and Switzerland
        c("NO", "NOR", .europe, euDocs), c("IS", "ISL", .europe, euDocs), c("LI", "LIE", .europe, euDocs),
        c("CH", "CHE", .europe, euDocs),
        // Rest of Europe
        c("GB", "GBR", .europe, [.passport, .residencePermit, .drivingLicence]),
        c("AD", "AND", .europe, europeDocs), c("MC", "MCO", .europe, europeDocs), c("SM", "SMR", .europe, europeDocs),
        c("VA", "VAT", .europe, [.passport]), c("AL", "ALB", .europe, europeDocs), c("BA", "BIH", .europe, europeDocs),
        c("ME", "MNE", .europe, europeDocs), c("MK", "MKD", .europe, europeDocs), c("RS", "SRB", .europe, europeDocs),
        c("XK", "RKS", .europe, europeDocs), c("MD", "MDA", .europe, europeDocs), c("UA", "UKR", .europe, europeDocs),
        c("BY", "BLR", .europe, europeDocs), c("RU", "RUS", .europe, [.passport, .drivingLicence]),
        c("TR", "TUR", .europe, europeDocs), c("GE", "GEO", .europe, europeDocs), c("AM", "ARM", .europe, europeDocs),
        c("AZ", "AZE", .europe, europeDocs),
        // North America
        c("US", "USA", .northAmerica, [.passport, .idCard, .drivingLicence]),
        c("CA", "CAN", .northAmerica, [.passport, .idCard, .drivingLicence]),
        c("MX", "MEX", .northAmerica, [.passport, .idCard, .drivingLicence]),
        // Oceania
        c("AU", "AUS", .oceania, [.passport, .drivingLicence]),
        c("NZ", "NZL", .oceania, [.passport, .drivingLicence]),
        // East Asia
        c("CN", "CHN", .eastAsia, [.passport, .idCard, .drivingLicence]),
        c("HK", "HKG", .eastAsia, [.passport, .idCard, .drivingLicence]),
        c("TW", "TWN", .eastAsia, [.passport, .idCard, .drivingLicence]),
        c("JP", "JPN", .eastAsia, [.passport, .idCard, .residencePermit, .drivingLicence]),
        c("KR", "KOR", .eastAsia, [.passport, .idCard, .drivingLicence]),
        // Southeast Asia
        c("SG", "SGP", .southeastAsia, [.passport, .idCard, .drivingLicence]),
        c("MY", "MYS", .southeastAsia, [.passport, .idCard, .drivingLicence]),
        // Other
        c("IN", "IND", .other, [.passport, .idCard, .drivingLicence]),
        c("BR", "BRA", .other, [.passport, .idCard, .drivingLicence]),
    ]

    /// The first supported countries: the most common documents among people who move between
    /// Europe, North America, Oceania and East and Southeast Asia. Grows as each is tested.
    public static let supported: Set<String> = [
        "NL", "DE", "FR", "GB", "IT", "ES", "NO", "SE", "DK", "FI", "BE", "PL", "IE", "CH", "AT", "PT",
        "US", "CA", "AU", "NZ", "CN", "HK", "TW", "JP", "KR", "SG", "MY",
    ]

    public static let byCode: [String: Country] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
    static let byMRZ: [String: Country] = {
        var map = Dictionary(uniqueKeysWithValues: all.map { ($0.mrzCode, $0) })
        // Codes of British nationality classes and Germany written with fillers.
        for code in ["GBD", "GBN", "GBO", "GBP", "GBS"] { map[code] = byCode["GB"] }
        map["D<<"] = byCode["DE"]
        map["DEU"] = byCode["DE"]
        return map
    }()

    public static func country(mrzCode: String) -> Country? {
        byMRZ[mrzCode] ?? byMRZ[mrzCode.replacingOccurrences(of: "<", with: "")]
    }

    /// Words printed on documents that name the issuing country, folded to upper case without diacritics.
    /// Longer phrases are tried first.
    static let keywords: [(String, String)] = {
        let table: [String: [String]] = [
            "NL": ["KONINKRIJK DER NEDERLANDEN", "NEDERLAND", "NEDERLANDSE IDENTITEITSKAART"],
            "BE": ["BELGIE", "BELGIQUE", "BELGIEN", "BELGIUM"],
            "DE": ["BUNDESREPUBLIK DEUTSCHLAND", "DEUTSCHLAND", "PERSONALAUSWEIS"],
            "AT": ["REPUBLIK OSTERREICH", "OSTERREICH"],
            "FR": ["REPUBLIQUE FRANCAISE", "CARTE NATIONALE D'IDENTITE"],
            "IT": ["REPUBBLICA ITALIANA", "CARTA DI IDENTITA", "PATENTE DI GUIDA"],
            "ES": ["REINO DE ESPANA", "DOCUMENTO NACIONAL DE IDENTIDAD", "PERMISO DE CONDUCCION"],
            "PT": ["REPUBLICA PORTUGUESA", "CARTAO DE CIDADAO", "CARTA DE CONDUCAO"],
            "SE": ["SVERIGE", "KORKORT"],
            "NO": ["NORGE", "NOREG", "FØRERKORT", "FORERKORT"],
            "DK": ["DANMARK", "KØREKORT", "KOREKORT"],
            "FI": ["SUOMI", "AJOKORTTI"],
            "IS": ["ISLAND", "OKUSKIRTEINI"],
            "PL": ["RZECZPOSPOLITA POLSKA", "PRAWO JAZDY", "DOWOD OSOBISTY"],
            "CZ": ["CESKA REPUBLIKA", "RIDICSKY PRUKAZ", "OBCANSKY PRUKAZ"],
            "SK": ["SLOVENSKA REPUBLIKA", "VODICSKY PREUKAZ"],
            "HU": ["MAGYARORSZAG", "JOGOSITVANY"],
            "RO": ["ROMANIA", "PERMIS DE CONDUCERE"],
            "BG": ["РЕПУБЛИКА БЪЛГАРИЯ", "BULGARIA"],
            "HR": ["REPUBLIKA HRVATSKA", "VOZACKA DOZVOLA"],
            "SI": ["REPUBLIKA SLOVENIJA", "VOZNISKO DOVOLJENJE"],
            "GR": ["ΕΛΛΗΝΙΚΗ ΔΗΜΟΚΡΑΤΙΑ", "HELLENIC REPUBLIC"],
            "CY": ["ΚΥΠΡΙΑΚΗ ΔΗΜΟΚΡΑΤΙΑ", "REPUBLIC OF CYPRUS"],
            "MT": ["MALTA"],
            "IE": ["EIRE", "IRELAND", "CEADUNAS TIOMANA"],
            "LU": ["LUXEMBOURG", "LETZEBUERG"],
            "LV": ["LATVIJAS REPUBLIKA", "LATVIJA"],
            "LT": ["LIETUVOS RESPUBLIKA", "LIETUVA"],
            "EE": ["EESTI"],
            "CH": ["SCHWEIZERISCHE EIDGENOSSENSCHAFT", "SCHWEIZ", "SUISSE", "SVIZZERA"],
            "LI": ["LIECHTENSTEIN"],
            "GB": ["UNITED KINGDOM", "GREAT BRITAIN", "DVLA"],
            "UA": ["УКРАЇНА", "UKRAINE"],
            "TR": ["TURKIYE CUMHURIYETI", "TURKIYE"],
            "RS": ["РЕПУБЛИКА СРБИЈА", "REPUBLIKA SRBIJA"],
            "MD": ["REPUBLICA MOLDOVA"],
            "AL": ["REPUBLIKA E SHQIPERISE"],
            "US": [
                "UNITED STATES", "USA", "DRIVER LICENSE", "ALABAMA", "ALASKA", "ARIZONA", "ARKANSAS", "CALIFORNIA", "COLORADO",
                "CONNECTICUT", "DELAWARE", "FLORIDA", "GEORGIA", "HAWAII", "IDAHO", "ILLINOIS", "INDIANA", "IOWA", "KANSAS",
                "KENTUCKY", "LOUISIANA", "MAINE", "MARYLAND", "MASSACHUSETTS", "MICHIGAN", "MINNESOTA", "MISSISSIPPI",
                "MISSOURI", "MONTANA", "NEBRASKA", "NEVADA", "NEW HAMPSHIRE", "NEW JERSEY", "NEW MEXICO", "NEW YORK",
                "NORTH CAROLINA", "NORTH DAKOTA", "OHIO", "OKLAHOMA", "OREGON", "PENNSYLVANIA", "RHODE ISLAND",
                "SOUTH CAROLINA", "SOUTH DAKOTA", "TENNESSEE", "TEXAS", "UTAH", "VERMONT", "VIRGINIA", "WASHINGTON",
                "WEST VIRGINIA", "WISCONSIN", "WYOMING",
            ],
            "CA": ["CANADA", "ONTARIO", "QUEBEC", "BRITISH COLUMBIA", "ALBERTA", "MANITOBA", "SASKATCHEWAN", "NOVA SCOTIA", "NEW BRUNSWICK"],
            "MX": ["ESTADOS UNIDOS MEXICANOS", "MEXICO"],
            "AU": ["AUSTRALIA", "NEW SOUTH WALES", "QUEENSLAND", "WESTERN AUSTRALIA", "SOUTH AUSTRALIA", "TASMANIA", "VICROADS", "NORTHERN TERRITORY"],
            "NZ": ["NEW ZEALAND", "WAKA KOTAHI", "AOTEAROA"],
            "CN": ["中华人民共和国", "居民身份证", "机动车驾驶证"],
            "HK": ["HONG KONG", "香港"],
            "TW": ["中華民國", "TAIWAN", "國民身分證"],
            "JP": ["日本国", "運転免許証", "個人番号カード", "在留カード", "JAPAN"],
            "KR": ["대한민국", "주민등록증", "운전면허증", "REPUBLIC OF KOREA"],
            "SG": ["REPUBLIC OF SINGAPORE", "SINGAPORE"],
            "MY": ["KAD PENGENALAN", "MYKAD", "MALAYSIA"],
            "IN": ["INDIA", "भारत"],
            "BR": ["REPUBLICA FEDERATIVA DO BRASIL", "BRASIL"],
        ]
        return table.flatMap { code, words in words.map { ($0, code) } }.sorted { $0.0.count > $1.0.count }
    }()

    static let documentKeywords: [(String, DocumentKind)] = [
        ("RESIDENCE PERMIT", .residencePermit), ("VERBLIJFSDOCUMENT", .residencePermit), ("VERBLIJFSVERGUNNING", .residencePermit),
        ("OPPHOLDSKORT", .residencePermit), ("OPPHOLDSTILLATELSE", .residencePermit), ("AUFENTHALTSTITEL", .residencePermit),
        ("TITRE DE SEJOUR", .residencePermit), ("PERMESSO DI SOGGIORNO", .residencePermit), ("UPPEHALLSTILLSTAND", .residencePermit),
        ("在留カード", .residencePermit),
        ("DRIVER LICENSE", .drivingLicence), ("DRIVER'S LICENCE", .drivingLicence), ("DRIVER LICENCE", .drivingLicence),
        ("DRIVING LICENCE", .drivingLicence), ("DRIVER'S LICENSE", .drivingLicence), ("RIJBEWIJS", .drivingLicence),
        ("FUHRERSCHEIN", .drivingLicence), ("PERMIS DE CONDUIRE", .drivingLicence), ("PATENTE DI GUIDA", .drivingLicence),
        ("PERMISO DE CONDUCCION", .drivingLicence), ("FØRERKORT", .drivingLicence), ("KORKORT", .drivingLicence),
        ("KØREKORT", .drivingLicence), ("AJOKORTTI", .drivingLicence), ("PRAWO JAZDY", .drivingLicence),
        ("RIDICSKY PRUKAZ", .drivingLicence), ("JOGOSITVANY", .drivingLicence), ("PERMIS DE CONDUCERE", .drivingLicence),
        ("SURUCU BELGESI", .drivingLicence), ("机动车驾驶证", .drivingLicence), ("運転免許証", .drivingLicence),
        ("운전면허증", .drivingLicence), ("LESEN MEMANDU", .drivingLicence),
        ("PASSPORT", .passport), ("PASSEPORT", .passport), ("REISEPASS", .passport), ("PASPOORT", .passport),
        ("PASAPORTE", .passport), ("PASSAPORTO", .passport), ("PASS", .passport), ("护照", .passport), ("護照", .passport),
        ("旅券", .passport), ("여권", .passport), ("PASZPORT", .passport),
        ("IDENTITY CARD", .idCard), ("CARTE D'IDENTITE", .idCard), ("CARTE NATIONALE", .idCard), ("IDENTITEITSKAART", .idCard),
        ("PERSONALAUSWEIS", .idCard), ("IDENTITETSKORT", .idCard), ("CARTA DI IDENTITA", .idCard), ("DOCUMENTO NACIONAL", .idCard),
        ("居民身份证", .idCard), ("身份證", .idCard), ("身分證", .idCard), ("주민등록증", .idCard), ("個人番号カード", .idCard), ("KAD PENGENALAN", .idCard),
        ("MYKAD", .idCard), ("NRIC", .idCard), ("ID CARD", .idCard), ("CARTAO DE CIDADAO", .idCard), ("DOWOD OSOBISTY", .idCard),
    ]
}
