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
    }
}
