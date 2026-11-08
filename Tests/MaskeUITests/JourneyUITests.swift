import XCTest

final class JourneyUITests: XCTestCase {
    private var fixture: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/synthetic/passport-nor.png").path
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomeAndDocuments() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Choose photos"].waitForExistence(timeout: 5))
        capture("Home", app: app)
        app.buttons["Documents"].tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 5))
        capture("Documents", app: app)
        let search = app.searchFields["Search countries"]
        search.tap()
        search.typeText("Norway")
        XCTAssertTrue(app.staticTexts["Norway"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["France"].exists)
    }

    func testReviewAndShare() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", fixture, "-MaskeRecipient", "Hotel Nord", "-MaskePurpose", "Check-in"]
        app.launch()
        XCTAssertTrue(app.buttons["Photo"].firstMatch.waitForExistence(timeout: 60))
        capture("Review", app: app)
        app.buttons["Continue"].tap()
        let share = app.buttons["Share copy"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: share)
        wait(for: [ready], timeout: 10)
        capture("Share", app: app)
        app.buttons["Preview copy"].tap()
        XCTAssertTrue(app.sliders["Zoom"].waitForExistence(timeout: 5))
        app.sliders["Zoom"].adjust(toNormalizedSliderPosition: 0.2)
        capture("Copy preview", app: app)
        app.navigationBars["Copy"].buttons["Done"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        app.navigationBars["Share"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Choose photos"].waitForExistence(timeout: 5))
    }

    func testUnreadableImportShowsRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", "/tmp/maske-missing-synthetic-fixture.png"]
        app.launch()
        XCTAssertTrue(app.alerts["Couldn’t open document"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Choose photos"].exists)
    }

    func testMaskMenuAndDrawing() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", fixture]
        app.launch()
        let photo = app.buttons["mask-photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 60))
        app.buttons["Masks"].tap()
        capture("Mask types", app: app)
        let photoType = app.descendants(matching: .any)["mask-type-photo"].firstMatch
        XCTAssertTrue(photoType.waitForExistence(timeout: 5))
        photoType.tap()
        XCTAssertEqual(photo.value as? String, "Shown")
        app.buttons["Masks"].tap()
        photoType.tap()
        XCTAssertEqual(photo.value as? String, "Hidden")
        app.buttons["Add box"].tap()
        let canvas = app.otherElements["page-canvas"].firstMatch
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.60)))
        XCTAssertTrue(app.navigationBars["Adjust box"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["mask-custom"].firstMatch.exists)
    }

    func testKeyboardAndSharingLatestCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", fixture]
        app.launch()
        XCTAssertTrue(app.buttons["mask-photo"].firstMatch.waitForExistence(timeout: 60))
        app.buttons["Continue"].tap()
        let share = app.buttons["Share copy"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(share.isEnabled)
        let recipient = app.textFields["recipient-field"]
        recipient.tap()
        recipient.typeText("Hotel Nord Reservation Office\n")
        let purpose = app.textFields["purpose-field"]
        let visibleInput = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let keyboard = app.keyboards.firstMatch
            return keyboard.exists && purpose.frame.maxY <= keyboard.frame.minY
                && purpose.frame.minY >= app.navigationBars["Share"].frame.maxY
        }, object: nil)
        wait(for: [visibleInput], timeout: 5)
        capture("Keyboard fields", app: app)
        purpose.typeText("Check-in only\n")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: share)
        wait(for: [ready], timeout: 10)
        XCTAssertEqual(recipient.value as? String, "Hotel Nord Reservation Office")
        XCTAssertEqual(purpose.value as? String, "Check-in only")
        capture("Entered copy details", app: app)
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
        capture("System share sheet", app: app)
        app.buttons["header.closeButton"].tap()
        XCTAssertEqual(recipient.value as? String, "Hotel Nord Reservation Office")
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"),
                                                 object: app.navigationBars["Share"].buttons["Done"])
        wait(for: [returned], timeout: 5)
    }
}
