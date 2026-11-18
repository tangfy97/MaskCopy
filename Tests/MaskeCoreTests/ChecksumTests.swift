import XCTest
@testable import MaskeCore

/// Published example numbers (specimens, not real people).
final class ChecksumTests: XCTestCase {
    func testEurope() {
        XCTAssertTrue(Checksum.dutchBSN("111222333"))
        XCTAssertFalse(Checksum.dutchBSN("111222334"))
        XCTAssertTrue(Checksum.italianFiscalCode("RSSMRA85T10A562S"))
        XCTAssertFalse(Checksum.italianFiscalCode("RSSMRA85T10A562T"))
        XCTAssertTrue(Checksum.spanishDNI("12345678Z"))
        XCTAssertFalse(Checksum.spanishDNI("12345678A"))
        XCTAssertTrue(Checksum.polishPESEL("44051401359"))
        XCTAssertFalse(Checksum.polishPESEL("44051401358"))
        XCTAssertTrue(Checksum.finnishPersonalCode("131052-308T"))
        XCTAssertTrue(Checksum.swedishPersonalNumber("811218-9876"))
        XCTAssertFalse(Checksum.swedishPersonalNumber("811218-9877"))
        let d = (0...9).lazy.map { [0, 1, 0, 1, 9, 0, 1, 2, $0] }.first { Checksum.norwegianControlDigits($0) != nil }!
        let k = Checksum.norwegianControlDigits(d)!
        XCTAssertTrue(Checksum.norwegianBirthNumber(d.map(String.init).joined() + "\(k.0)\(k.1)"))
    }

    func testAmericasAndAsia() {
        XCTAssertTrue(Checksum.brazilianCPF("111.444.777-35"))
        XCTAssertTrue(Checksum.chineseResidentID("11010519491231002X"))
        XCTAssertFalse(Checksum.chineseResidentID("110105194912310021"))
        XCTAssertTrue(Checksum.hongKongID("A123456(3)"))
        XCTAssertFalse(Checksum.hongKongID("A123456(4)"))
        XCTAssertTrue(Checksum.taiwanID("A123456789"))
        XCTAssertFalse(Checksum.taiwanID("A123456788"))
        XCTAssertTrue(Checksum.singaporeNRIC("S1234567D"))
        XCTAssertFalse(Checksum.singaporeNRIC("S1234567A"))
    }

    func testUnitedStatesAndCanada() {
        // Canada's published test SIN; Luhn-valid made-up health numbers; BC Ministry of Health's worked PHN.
        XCTAssertTrue(Checksum.canadianSIN("046 454 286"))
        XCTAssertFalse(Checksum.canadianSIN("046 454 287"))
        XCTAssertFalse(Checksum.canadianSIN("800 000 002")) // 8 is for business numbers
        XCTAssertTrue(Checksum.ontarioHealthNumber("1234-567-897"))
        XCTAssertFalse(Checksum.ontarioHealthNumber("1234-567-898"))
        XCTAssertTrue(Checksum.britishColumbiaHealthNumber("9698 658 215"))
        XCTAssertFalse(Checksum.britishColumbiaHealthNumber("9698 658 216"))
        XCTAssertTrue(Checksum.quebecHealthNumber("TREM 8557 1512")) // born 15 July 1985, female (+50)
        XCTAssertFalse(Checksum.quebecHealthNumber("TREM 8513 1512"))
        XCTAssertTrue(Checksum.quebecLicence("T6512-150785-01"))
        XCTAssertFalse(Checksum.quebecLicence("T6512-159985-01"))
        XCTAssertFalse(Checksum.usSocialSecurityNumber("912-34-5678")) // ITIN range
        // CMS's published example Medicare number.
        let mbi = NumberPattern.all.first { $0.name == "US Medicare number" }!
        for (s, found) in [("1EG4-TE5-MK73", true), ("1EG4TE5MK73", true), ("1SG4-TE5-MK73", false)] {
            XCTAssertEqual(mbi.regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil, found, s)
        }
    }

    func testMiddleEast() {
        // Made-up numbers built with the published Luhn rule.
        XCTAssertTrue(Checksum.saudiIdentityNumber("1012345672"))
        XCTAssertTrue(Checksum.saudiIdentityNumber("2123456788"))
        XCTAssertFalse(Checksum.saudiIdentityNumber("2123456786"))
        XCTAssertFalse(Checksum.saudiIdentityNumber("3123456782"))
        XCTAssertTrue(Checksum.egyptianNationalNumber("29001010112345"))
        XCTAssertTrue(Checksum.egyptianNationalNumber("30512250212345"))
        XCTAssertFalse(Checksum.egyptianNationalNumber("29013010112345")) // month 13
        XCTAssertFalse(Checksum.egyptianNationalNumber("29001010512345")) // no governorate 05
        XCTAssertFalse(Checksum.egyptianNationalNumber("19001010112345"))
    }

    func testIndiaChinaAndAustralia() {
        // ABR's published ABN example; ATO TFN rule; Medicare rule.
        XCTAssertTrue(Checksum.australianTFN("876 543 210"))
        XCTAssertTrue(Checksum.australianTFN("123 456 782"))
        XCTAssertFalse(Checksum.australianTFN("123 456 789"))
        XCTAssertTrue(Checksum.australianMedicare("3189 97702 1"))
        XCTAssertFalse(Checksum.australianMedicare("3189 97703 1"))
        XCTAssertFalse(Checksum.australianMedicare("1189 97702 1"), "first digit 2–6")
        XCTAssertTrue(Checksum.indianGSTIN("27AAPFU0939F1ZV"))
        XCTAssertFalse(Checksum.indianGSTIN("27AAPFU0939F1ZW"))
        XCTAssertTrue(Checksum.chineseSocialCreditCode("91350100M000100Y43"))
        XCTAssertFalse(Checksum.chineseSocialCreditCode("91350100M000100Y44"))
        XCTAssertFalse(Checksum.chineseSocialCreditCode("91350100M000100Y4I"), "I is not in the code's alphabet")
        XCTAssertTrue(Checksum.paymentCard("6222 0212 3456 7890 128"))
        XCTAssertFalse(Checksum.paymentCard("6222 0212 3456 7890 129"))
        XCTAssertTrue(Checksum.chineseForeignResidentOld("USA110089123145"))
        XCTAssertFalse(Checksum.chineseForeignResidentOld("USA110089133145"))
    }

    func testSpainFranceAndDenmark() {
        // The AEAT's own NIF (Agencia Estatal de Administración Tributaria) is a published company NIF.
        XCTAssertTrue(Checksum.spanishCompanyNIF("Q2826000H"))
        XCTAssertFalse(Checksum.spanishCompanyNIF("Q28260008"), "Q entities take a letter")
        XCTAssertTrue(Checksum.spanishCompanyNIF("B12345674"))
        XCTAssertFalse(Checksum.spanishCompanyNIF("B12345675"))
        XCTAssertFalse(Checksum.spanishCompanyNIF("12345678Z"), "a person's DNI is not a company NIF")
        // Seguridad Social: both readings of the mod 97 rule (number above and below 10 000 000).
        XCTAssertTrue(Checksum.spanishSocialSecurity("28/12345678/40"))
        XCTAssertTrue(Checksum.spanishSocialSecurity("08 01234567 74"))
        XCTAssertFalse(Checksum.spanishSocialSecurity("28/12345678/41"))
        XCTAssertFalse(Checksum.spanishSocialSecurity("99/12345678/40"), "no province 99")
        // NIR: key 97 − n mod 97, Corsica 2A → 19, and 2A read by OCR as 24.
        XCTAssertTrue(Checksum.frenchNIR("1 85 05 75 112 233 44"))
        XCTAssertFalse(Checksum.frenchNIR("1 85 05 75 112 233 45"))
        XCTAssertTrue(Checksum.frenchNIR("2 90 01 2A 004 012 02"))
        XCTAssertTrue(Checksum.frenchNIR("2 90 01 24 004 012 02"))
    }

    func testUnitedKingdomAndGermany() {
        XCTAssertTrue(Checksum.britishNationalInsurance("AB 12 34 56 C"))
        XCTAssertFalse(Checksum.britishNationalInsurance("GB 12 34 56 C"))
        XCTAssertFalse(Checksum.britishNationalInsurance("DA 12 34 56 C"))
        XCTAssertFalse(Checksum.britishNationalInsurance("AB 12 34 56 E"))
        XCTAssertTrue(Checksum.nhsNumber("943 476 5919")) // NHS Data Dictionary
        XCTAssertFalse(Checksum.nhsNumber("943 476 5918"))
        for id in ["86095742719", "47036892816", "65929970489", "57549285017", "25768131411"] { // BZSt examples
            XCTAssertTrue(Checksum.germanTaxID(id), id)
        }
        XCTAssertFalse(Checksum.germanTaxID("86095742718"))
        XCTAssertFalse(Checksum.germanTaxID("12345678903")) // no repeated digit
        XCTAssertTrue(Checksum.germanPensionNumber("15070649C103")) // Deutsche Rentenversicherung
        XCTAssertTrue(Checksum.germanPensionNumber("65 170839 J 003"))
        XCTAssertFalse(Checksum.germanPensionNumber("15070649C104"))
        XCTAssertFalse(Checksum.germanPensionNumber("15073249C103")) // day 32? month 32
        XCTAssertTrue(Checksum.germanHealthInsuranceNumber("A123456780"))
        XCTAssertFalse(Checksum.germanHealthInsuranceNumber("A123456781"))
    }

    func testEmiratesIDAndIBAN() {
        XCTAssertTrue(Checksum.emiratesID("784-1990-1234567-6"))
        XCTAssertFalse(Checksum.emiratesID("784-1990-1234567-5"))
        XCTAssertFalse(Checksum.emiratesID("785-1990-1234567-1"))
        // Examples from the SWIFT IBAN registry.
        for s in ["NL91 ABNA 0417 1643 00", "GB82 WEST 1234 5698 7654 32", "SA03 8000 0000 6080 1016 7519",
                  "AE07 0331 2345 6789 0123 456", "DE89 3704 0044 0532 0130 00"] {
            XCTAssertTrue(Checksum.iban(s), s)
        }
        XCTAssertFalse(Checksum.iban("NL91 ABNA 0417 1643 01"))
        XCTAssertFalse(Checksum.iban("NL91 ABNA 0417 1643 0"))
        let iban = NumberPattern.all.first { $0.name == "IBAN" }!
        let line = "IBAN: SA03 8000 0000 6080 1016 7519"
        let m = iban.regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))!
        XCTAssertTrue(iban.validate((line as NSString).substring(with: m.range)))
    }

    func testMRZ() {
        // ICAO 9303 specimen passport.
        let mrz = MRZReader.parse([
            "P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<",
            "L898902C36UTO7408122F1204159ZE184226B<<<<<10",
        ])
        XCTAssertEqual(mrz?.format, .td3)
        XCTAssertEqual(mrz?.documentNumber, "L898902C3")
        XCTAssertEqual(mrz?.personalNumber, "ZE184226B")
        XCTAssertEqual(mrz?.checksumsValid, true)
        XCTAssertEqual(mrz?.documentKind, .passport)

        // ICAO 9303 specimen ID card.
        let td1 = MRZReader.parse([
            "I<UTOD231458907<<<<<<<<<<<<<<<",
            "7408122F1204159UTO<<<<<<<<<<<6",
            "ERIKSSON<<ANNA<MARIA<<<<<<<<<<",
        ])
        XCTAssertEqual(td1?.format, .td1)
        XCTAssertEqual(td1?.documentNumber, "D23145890")
        XCTAssertEqual(td1?.checksumsValid, true)
        XCTAssertEqual(td1?.documentKind, .idCard)

        // A TD1 first line with no filler (the Emirates ID number fills the optional data).
        XCTAssertTrue(MRZReader.isFullTD1FirstLine("ILARE1234567897784199012345676"))
        XCTAssertFalse(MRZReader.isFullTD1FirstLine("ILARE1234567898784199012345676"))
    }
}
