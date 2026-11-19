import XCTest

final class TourUITests: XCTestCase {
    func testFirstInstallShowsTheWholeTour() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeTourSeen", "0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Covers what they don’t need"].waitForExistence(timeout: 5))
        // App Store builds add a page after the first.
        for _ in 0..<2 where !app.staticTexts["Mark who it’s for"].exists {
            app.buttons["Continue"].tap()
            _ = app.staticTexts["Mark who it’s for"].waitForExistence(timeout: 2)
        }
        XCTAssertTrue(app.staticTexts["Mark who it’s for"].exists)
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
        app.launchArguments = ["-MaskeTourSeen", "3"]
        app.launch()
        XCTAssertTrue(app.buttons["Scan document"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Skip"].exists)
    }
}
