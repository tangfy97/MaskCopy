import XCTest

/// Run only on an isolated simulator containing one generated fixture, never a personal library.
final class ImportUITests: XCTestCase {
    func testSyntheticPhotoImport() throws {
        guard ProcessInfo.processInfo.environment["MASKCOPY_SYNTHETIC_PHOTO_IMPORT"] == "1" else {
            throw XCTSkip("Requires an isolated simulator seeded with one generated passport")
        }
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choose photos"].tap()
        let pickerBar = app.navigationBars["Photos"]
        XCTAssertTrue(pickerBar.waitForExistence(timeout: 10))
        let onboardingClose = app.buttons["Close"].firstMatch
        if onboardingClose.exists { onboardingClose.tap() }
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "System photo picker"
        picker.lifetime = .keepAlways
        add(picker)
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo,'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
        photo.tap()
        let done = pickerBar.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        XCTAssertTrue(app.buttons["mask-photo"].firstMatch.waitForExistence(timeout: 60))
        app.buttons["Continue"].tap()
        let recipient = app.textFields["recipient-field"]
        XCTAssertTrue(recipient.waitForExistence(timeout: 5))
        recipient.tap()
        recipient.typeText("Test Hotel\n")
        app.textFields["purpose-field"].typeText("Check-in only\n")
        app.buttons["Preview copy"].tap()
        XCTAssertTrue(app.navigationBars["Your copy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Share copy"].isEnabled)
        let copy = XCTAttachment(screenshot: app.screenshot())
        copy.name = "Imported fixture copy"
        copy.lifetime = .keepAlways
        add(copy)
    }
}
