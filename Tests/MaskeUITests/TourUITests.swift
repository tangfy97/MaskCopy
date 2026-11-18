import XCTest

final class TourUITests: XCTestCase {
    func testFirstInstallShowsTheWholeTour() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeTourSeen", "0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Covers what they don’t need"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Mark who it’s for"].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["30 countries"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Skip"].exists)
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Scan document"].waitForExistence(timeout: 3))
    }

    func testUpdateShowsTheWholeTourAndCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeTourSeen", "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Covers what they don’t need"].waitForExistence(timeout: 5))
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
