import Foundation

/// Field labels printed next to (or above) a value that should be hidden, folded to upper case
/// without diacritics. Matched as whole words, so short ones such as "FIN" don't match "FINLAND".
enum Labels {
    static let personalNumber: [String] = [
        // English and international
        "PERSONAL NO", "PERSONAL NUMBER", "PERSONAL CODE", "PERSONAL ID", "PERSON ID", "NATIONAL NUMBER", "NATIONAL NO", "NATIONAL ID",
        "IDENTIFICATION NO", "IDENTITY NO", "ID NO", "SOCIAL SECURITY", "SSN", "SOCIAL INSURANCE",
        // Europe
        "PERSOONSNUMMER", "BSN", "BURGERSERVICENUMMER", "RIJKSREGISTERNUMMER", "RIJKSREGISTERNR", "NATIONAALNUMMER",
        "N° NATIONAL", "NUMERO NATIONAL", "NATIONALNUMMER", "MATRICULE", "FØDSELSNUMMER", "FODSELSNUMMER", "PERSONNUMMER",
        "PERSONNR", "CPR", "PERSONNUMMER/PERSONAL", "HENKILOTUNNUS", "KENNITALA", "ISIKUKOOD", "ASMENS KODAS", "PERSONAS KODS",
        "PESEL", "RODNE CISLO", "CNP", "ЕГН", "EGN", "OIB", "EMSO", "JMBG", "ЈМБГ", "CODICE FISCALE", "NIF", "NISS",
        "IDENTIFICACAO CIVIL", "PPS", "AHV", "AVS", "SZEMELYI AZONOSITO", "KIMLIK NO", "T.C. KIMLIK", "УНЗР", "ЗАПИС №",
        "IDNP", "NUMRI PERSONAL", "NI NO", "NI NUMBER", "NINO", "NATIONAL INSURANCE", "NHS NO", "NHS NUMBER", "UTR",
        "UNIQUE TAXPAYER REFERENCE", "SHARE CODE", "SORT CODE", "ACCOUNT NO", "ACCOUNT NUMBER", "A/C NO", "STEUER-ID",
        "STEUER-IDNR", "IDNR", "IDENTIFIKATIONSNUMMER", "STEUERLICHE IDENTIFIKATIONSNUMMER", "SV-NUMMER", "SV-NR",
        "SOZIALVERSICHERUNGSNUMMER", "RV-NUMMER", "RENTENVERSICHERUNGSNUMMER", "VERSICHERTENNUMMER", "VERSICHERTEN-NR",
        "KRANKENVERSICHERTENNUMMER", "KV-NR", "KONTONUMMER", "V-NUMMER", "V-NR", "VREEMDELINGENNUMMER", "BSN/SOFINR",
        "SOFINUMMER", "SOFI-NR", "POLISNUMMER", "ZORGVERZEKERINGSNUMMER", "REKENINGNUMMER", "NUSS", "N.A.F.", "AFILIACION",
        "NUM. AFILIACION", "CIP", "CIPA", "CIP-SNS", "NUHSA", "TIS", "TARJETA SANITARIA", "CODIGO SNS", "CUENTA BANCARIA",
        "N° SS", "N° SECU", "NIR", "NUMERO DE SECURITE SOCIALE", "N° DE SECURITE SOCIALE", "N° FISCAL", "NUMERO FISCAL",
        "IDENTIFIANT FISCAL", "N° ALLOCATAIRE", "NUMERO D'ALLOCATAIRE", "NUMERO ALLOCATAIRE", "N° ETRANGER",
        "NUMERO ETRANGER", "AGDREF", "NEPH", "REG.NR", "REG. NR", "KONTONR", "KONTO NR", "KONTO", "REG./KONTO",
        "LICHNY NOMER", "ИДЕНТИФИКАЦИОННЫЙ НОМЕР", "PERSONLIG ID",
        // Americas
        "CURP", "CPF", "USCIS#", "USCIS #", "USCIS NO", "USCIS NUMBER", "A#", "A #", "A-NUMBER", "A NUMBER", "ALIEN NUMBER",
        "ALIEN REGISTRATION", "ALIEN NO", "MEDICARE NUMBER", "MEDICARE NO", "SIN NO", "NAS",
        "NUMERO D'ASSURANCE SOCIALE", "HEALTH NUMBER", "HEALTH CARD NUMBER", "HEALTH CARD NO", "PERSONAL HEALTH NUMBER", "PHN",
        "NUMERO DE LA CARTE SANTE", "NUMERO D'ASSURANCE MALADIE", "UCI", "IUC", "CLIENT ID", "N° ID", "NO ID",
        // Middle East and North Africa
        "رقم الهوية", "رقم الهوية الوطنية", "رقم السجل المدني", "السجل المدني", "رقم الإقامة", "رقم الاقامة", "رقم الحدود",
        "الرقم القومي", "رقم قومي", "الرقم القومى", "ID NUMBER", "IQAMA NO", "IQAMA NUMBER",
        "TRAFFIC CODE NO", "TRAFFIC CODE", "TRAFFIC FILE NO", "T.C. NO", "TC NO", "رقم الملف المروري", "الرمز المروري",
        "IBAN", "CIVIL REGISTRY", "BORDER NO",
        // Asia
        "公民身份号码", "公民身份號碼", "身份证号", "身份證號", "身分證統一編號", "統一編號", "個人番号", "주민등록번호",
        "NRIC", "FIN", "NO. KP", "NO KP", "NO. K/P", "IDENTITY CARD NO", "I/C NO", "AADHAAR",
        "VID", "VIRTUAL ID", "EPIC", "EPIC NO", "FILE NO", "FILE NUMBER", "UAN", "UNIVERSAL ACCOUNT NUMBER", "ESIC", "ESIC NO",
        "IP NO", "IP NUMBER", "RATION CARD NO", "PAN", "PAN NO", "PERMANENT ACCOUNT NUMBER", "卡号", "社会保障号码", "社会保障卡号",
        "银行卡号", "账号", "银行账号",
        // Oceania
        "TFN", "TAX FILE NUMBER", "BSB", "ACC NO", "CRN", "CUSTOMER REFERENCE NUMBER", "IMMICARD NO", "VISA GRANT NUMBER",
    ]

    static let documentNumber: [String] = [
        "DOCUMENT NO", "DOCUMENT NUMBER", "DOC NO", "DOCUMENTNUMMER", "DOKUMENTNUMMER", "DOKUMENTNR", "PASSPORT NO",
        "PASSPORT NUMBER", "PASPOORTNUMMER", "PASSNUMMER", "PASSNR", "NUMERO DU DOCUMENT", "N° DU DOCUMENT",
        "NUMERO DE DOCUMENTO", "PASS(ERSATZ)", "PASSERSATZ", "N° DE REFERENCE", "NO DE REFERENCE", "NUMERO DE REFERENCE",
        "NUMERO DOCUMENTO", "NUM SOPORTE", "NUMERO DE SOPORTE", "CARD NO", "CARD NUMBER", "LICENCE NO", "LICENSE NO",
        "LICENCE NUMBER", "LICENSE NUMBER", "LIC NO", "LIC#", "DL NO", "DLN", "DL#", "ID#", "DD", "KARTNUMMER", "KORTNUMMER",
        "护照号", "护照号码", "護照號碼", "证号", "證號", "档案编号", "番号", "免許証番号", "旅券番号", "면허번호", "여권번호",
        "NO. PASPORT", "NO. LESEN", "CARD ACCESS", "PASSPORT CARD NO", "INVENTORY CONTROL", "ICN", "CARD#", "CARD #",
        "N° DE PASSEPORT", "NO DE PASSEPORT", "NUMERO DE PASSEPORT", "NUMERO DU PERMIS", "N° DU PERMIS", "NO DU PERMIS",
        "رقم الجواز", "رقم جواز السفر", "رقم الرخصة", "رقم رخصة القيادة", "رقم البطاقة", "رقم المصنع", "DRIVING LICENSE NO",
    ]

    static let address: [String] = [
        "ADDRESS", "RESIDENTIAL ADDRESS", "ADRES", "ADRESSE", "ADRESA", "ADRESAS", "ANSCHRIFT", "WOHNORT", "INDIRIZZO",
        "RESIDENZA", "住居地", "DIRECCION", "DOMICILIO", "MORADA", "OSOITE", "BOSTEDSADRESSE", "BOPÆL", "ADRESS", "LAKCIM",
        "ADRES ZAMIESZKANIA", "MIEJSCE ZAMIESZKANIA", "ΔΙΕΥΘΥΝΣΗ", "АДРЕС", "АДРЕСА", "住址", "住所", "주소", "ALAMAT", "S/O", "D/O", "W/O", "C/O",
        "العنوان", "عنوان", "محل الإقامة", "محل الاقامة", "جهة الإقامة",
    ]

    static let cardAccessNumber: [String] = ["CAN"]

    /// Labels of numbers that are not secret and stay visible: company registrations, tax codes and classes.
    static let keptNumbers: [String] = [
        "KVK", "KAMER VAN KOOPHANDEL", "TAX CODE", "STEUERKLASSE", "STKL", "COMPANY NO", "COMPANY NUMBER",
        "COMPANY REG", "HANDELSREGISTER", "HRB", "BTW", "VAT NO", "VAT REG", "UST-IDNR",
        "CIF", "C.I.F.", "CCC", "C.C.C.", "CODIGO CUENTA COTIZACION", "SIREN", "SIRET", "N° SIRET", "URSSAF", "CODE APE",
        "APE ", "CODE NAF", "CVR", "SE-NR", "ABN", "A.B.N.", "ACN", "A.C.N.", "TAN ", "TAN:", "GSTIN", "GST NO",
        "统一社会信用代码", "纳税人识别号", "税号",
    ]

    /// Names of fields that are not hidden. An address that runs over several lines stops at one.
    static let otherFields: [String] = [
        "وحدة مرور", "تاريخ", "الاسم", "الجنسية", "المهنة", "جهة العمل", "صاحب العمل", "فصيلة الدم", "الديانة",
        "الحالة الاجتماعية",
    ].map(\.foldedUpper)

    static let rules: [(FindingKind, [String])] = {
        // Folded like the text they are matched against (Arabic hamza forms lose their hamza).
        let table: [(FindingKind, [String])] = [
            (.personalNumber, personalNumber), (.documentNumber, documentNumber), (.address, address), (.cardAccessNumber, cardAccessNumber),
        ]
        return table.map { ($0.0, $0.1.map(\.foldedUpper)) }
    }()

    /// Field numbers used by the EU driving licence (Directive 2006/126/EC), ISO/IEC 18013-1 and AAMVA.
    static let fieldCodes: [String: FindingKind] = [
        "4D": .personalNumber, "5": .documentNumber, "5A": .documentNumber, "5B": .documentNumber, "8": .address,
    ]

    /// Codes that mark a numbered licence layout; finding a few of these at line starts means one.
    static let layoutCodes: Set<String> = ["1", "2", "3", "4A", "4B", "4C", "4D", "5", "7", "8", "9", "10", "11", "12"]
}
