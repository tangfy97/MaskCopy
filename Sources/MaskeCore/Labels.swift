import Foundation

/// Field labels printed next to (or above) a value that should be hidden, folded to upper case
/// without diacritics. Matched as whole words, so short ones such as "FIN" don't match "FINLAND".
enum Labels {
    static let personalNumber: [String] = [
        // English and international
        "PERSONAL NO", "PERSONAL NUMBER", "PERSONAL CODE", "PERSONAL ID", "NATIONAL NUMBER", "NATIONAL NO", "NATIONAL ID",
        "IDENTIFICATION NO", "IDENTITY NO", "ID NO", "SOCIAL SECURITY", "SSN", "SOCIAL INSURANCE",
        // Europe
        "PERSOONSNUMMER", "BSN", "BURGERSERVICENUMMER", "RIJKSREGISTERNUMMER", "RIJKSREGISTERNR", "NATIONAALNUMMER",
        "N° NATIONAL", "NUMERO NATIONAL", "NATIONALNUMMER", "MATRICULE", "FØDSELSNUMMER", "FODSELSNUMMER", "PERSONNUMMER",
        "PERSONNR", "CPR", "PERSONNUMMER/PERSONAL", "HENKILOTUNNUS", "KENNITALA", "ISIKUKOOD", "ASMENS KODAS", "PERSONAS KODS",
        "PESEL", "RODNE CISLO", "CNP", "ЕГН", "EGN", "OIB", "EMSO", "JMBG", "ЈМБГ", "CODICE FISCALE", "NIF", "NISS",
        "IDENTIFICACAO CIVIL", "PPS", "AHV", "AVS", "SZEMELYI AZONOSITO", "KIMLIK NO", "T.C. KIMLIK", "УНЗР", "ЗАПИС №",
        "IDNP", "NUMRI PERSONAL", "LICHNY NOMER", "ИДЕНТИФИКАЦИОННЫЙ НОМЕР", "PERSONLIG ID",
        // Americas
        "CURP", "CPF",
        // Asia
        "公民身份号码", "公民身份號碼", "身份证号", "身份證號", "身分證統一編號", "統一編號", "個人番号", "주민등록번호",
        "NRIC", "FIN", "NO. KP", "NO KP", "NO. K/P", "IDENTITY CARD NO", "I/C NO", "AADHAAR",
    ]

    static let documentNumber: [String] = [
        "DOCUMENT NO", "DOCUMENT NUMBER", "DOC NO", "DOCUMENTNUMMER", "DOKUMENTNUMMER", "DOKUMENTNR", "PASSPORT NO",
        "PASSPORT NUMBER", "PASPOORTNUMMER", "PASSNUMMER", "PASSNR", "NUMERO DU DOCUMENT", "N° DU DOCUMENT", "NUMERO DE DOCUMENTO",
        "NUMERO DOCUMENTO", "NUM SOPORTE", "NUMERO DE SOPORTE", "CARD NO", "CARD NUMBER", "LICENCE NO", "LICENSE NO",
        "LICENCE NUMBER", "LICENSE NUMBER", "LIC NO", "LIC#", "DL NO", "DLN", "DL#", "ID#", "DD", "KARTNUMMER", "KORTNUMMER",
        "护照号", "护照号码", "護照號碼", "证号", "證號", "档案编号", "番号", "免許証番号", "旅券番号", "면허번호", "여권번호",
        "NO. PASPORT", "NO. LESEN", "CARD ACCESS",
    ]

    static let address: [String] = [
        "ADDRESS", "RESIDENTIAL ADDRESS", "ADRES", "ADRESSE", "ADRESA", "ADRESAS", "ANSCHRIFT", "WOHNORT", "INDIRIZZO",
        "RESIDENZA", "住居地", "DIRECCION", "DOMICILIO", "MORADA", "OSOITE", "BOSTEDSADRESSE", "BOPÆL", "ADRESS", "LAKCIM",
        "ADRES ZAMIESZKANIA", "MIEJSCE ZAMIESZKANIA", "ΔΙΕΥΘΥΝΣΗ", "АДРЕС", "АДРЕСА", "住址", "住所", "주소", "ALAMAT",
    ]

    static let cardAccessNumber: [String] = ["CAN"]

    static var rules: [(FindingKind, [String])] {
        [(.personalNumber, personalNumber), (.documentNumber, documentNumber), (.address, address), (.cardAccessNumber, cardAccessNumber)]
    }

    /// Field numbers used by the EU driving licence (Directive 2006/126/EC), ISO/IEC 18013-1 and AAMVA.
    static let fieldCodes: [String: FindingKind] = [
        "4D": .personalNumber, "5": .documentNumber, "5A": .documentNumber, "5B": .documentNumber, "8": .address,
    ]

    /// Codes that mark a numbered licence layout; finding a few of these at line starts means one.
    static let layoutCodes: Set<String> = ["1", "2", "3", "4A", "4B", "4C", "4D", "5", "7", "8", "9", "10", "11", "12"]
}
