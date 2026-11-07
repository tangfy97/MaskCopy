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
