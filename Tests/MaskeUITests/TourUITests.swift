import XCTest

final class TourUITests: XCTestCase {
    func testFirstInstallShowsTheWholeTourWithNewPages() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeTourSeen", "0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Scan or choose a document"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["new-badge"].exists)
        for _ in 0..<3 { app.buttons["Continue"].tap() }
        XCTAssertTrue(app.staticTexts["Saudi Arabia and Egypt"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["new-badge"].exists)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["More US documents"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Skip"].exists)
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Scan document"].waitForExistence(timeout: 3))
    }

    func testUpdateShowsTheWholeTourAndCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeTourSeen", "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Scan or choose a document"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Scan document"].waitForExistence(timeout: 3))
    }

    func testNoTourOnceSeen() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeTourSeen", "2"]
        app.launch()
        XCTAssertTrue(app.buttons["Scan document"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Skip"].exists)
    }
}
