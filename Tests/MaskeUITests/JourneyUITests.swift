import XCTest

final class JourneyUITests: XCTestCase {
    private var fixture: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/synthetic/passport-nor.png").path
    }
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func documentApp(recipient: String = "Hotel Nord", purpose: String = "Check-in") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", fixture, "-MaskeRecipient", recipient, "-MaskePurpose", purpose]
        app.launch()
        XCTAssertTrue(app.buttons["mask-photo"].firstMatch.waitForExistence(timeout: 60))
        return app
    }
    private func openCopy(_ app: XCUIApplication) {
        app.buttons["Preview copy"].tap()
        XCTAssertTrue(app.navigationBars["Your copy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Share copy"].isEnabled)
    }
    func testHomeAndDocuments() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Choose photos"].waitForExistence(timeout: 5))
        capture("Home", app: app)
        app.buttons["Documents"].tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 5))
        capture("Documents", app: app)
        for name in ["Passport", "National ID card", "Residence permit", "Driving licence"] {
            let label = app.staticTexts[name].firstMatch
            for _ in 0..<8 {
                if label.isHittable { break }
                app.collectionViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(label.isHittable)
        }
        let countries = app.buttons["document-countries"]
        for _ in 0..<8 {
            if countries.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        countries.tap()
        let search = app.searchFields["Search countries"]
        search.tap()
        search.typeText("Norway")
        XCTAssertTrue(app.staticTexts["Norway"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["France"].exists)
        app.buttons["Norway"].tap()
        XCTAssertTrue(app.navigationBars["Norway"].waitForExistence(timeout: 5))
        let nationalID = app.staticTexts["National ID card"].firstMatch
        for _ in 0..<8 {
            if nationalID.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(nationalID.exists)
        XCTAssertTrue(app.staticTexts["Front and back"].firstMatch.exists)
        capture("Country documents", app: app)
    }
    func testReviewAndShare() {
        let app = documentApp()
        capture("Hide details", app: app)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.textFields["recipient-field"].waitForExistence(timeout: 5))
        capture("Watermark", app: app)
        openCopy(app)
        XCTAssertTrue(app.buttons["Save JPG"].exists)
        XCTAssertFalse(app.staticTexts["Step 3 of 3, Share"].exists)
        capture("Your copy", app: app)
        app.sliders["Zoom"].adjust(toNormalizedSliderPosition: 0.2)
        capture("Zoomed copy", app: app)
        app.navigationBars["Your copy"].buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Choose photos"].waitForExistence(timeout: 5))
    }

    func testPDFSavePickerAndReturningToTheCopy() {
        let app = documentApp(recipient: "Export test " + String(UUID().uuidString.prefix(8)))
        app.buttons["Continue"].tap()
        openCopy(app)
        app.segmentedControls.buttons["PDF"].tap()
        XCTAssertTrue(app.buttons["Save PDF"].isEnabled)
        app.buttons["Save PDF"].tap()
        XCTAssertTrue(app.buttons["DOCPicker.actionButton"].waitForExistence(timeout: 10))
        capture("Save PDF picker", app: app)
        app.buttons["DOCPicker.actionButton"].tap()
        XCTAssertTrue(app.buttons["copy-saved"].waitForExistence(timeout: 10))
        capture("Saved PDF", app: app)
        app.segmentedControls.buttons["JPG"].tap()
        app.buttons["Save JPG"].tap()
        XCTAssertTrue(app.buttons["DOCPicker.actionButton"].waitForExistence(timeout: 10))
        if app.buttons["Browse"].exists { app.buttons["Browse"].tap() }
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Save JPG"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["PDF"].tap()
        XCTAssertTrue(app.buttons["Share copy"].isEnabled)
        app.buttons["Share copy"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
        capture("Share PDF", app: app)
        app.buttons["header.closeButton"].tap()
    }
    func testUnreadableImportShowsRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", "/tmp/maske-missing-synthetic-fixture.png"]
        app.launch()
        XCTAssertTrue(app.alerts["Couldn’t open document"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Choose photos"].exists)
    }
    func testVisibleMaskControlsAndDrawing() {
        let app = documentApp()
        let photo = app.buttons["mask-photo"].firstMatch
        let toggle = app.switches["mask-type-photo"].firstMatch
        XCTAssertTrue(toggle.exists)
        if !toggle.isHittable { app.scrollViews.firstMatch.swipeUp() }
        toggle.tap()
        XCTAssertEqual(photo.value as? String, "Shown")
        toggle.tap()
        XCTAssertEqual(photo.value as? String, "Hidden")
        app.scrollViews.firstMatch.swipeDown()
        app.buttons["Add box"].tap()
        let canvas = app.otherElements["page-canvas"].firstMatch
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.45)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.60)))
        XCTAssertTrue(app.navigationBars["Adjust box"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["mask-custom"].firstMatch.exists)
    }
    func testKeyboardAndSharingLatestCopy() {
        let app = documentApp(recipient: "", purpose: "")
        app.buttons["Continue"].tap()
        let preview = app.buttons["Preview copy"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertFalse(preview.isEnabled)
        let recipient = app.textFields["recipient-field"]
        recipient.tap()
        recipient.typeText("Hotel Nord Reservation Office\n")
        let purpose = app.textFields["purpose-field"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let keyboard = app.keyboards.firstMatch
            return keyboard.exists && purpose.frame.maxY <= keyboard.frame.minY
                && purpose.frame.minY >= app.navigationBars["Watermark"].frame.maxY
        }, object: nil)
        wait(for: [visible], timeout: 5)
        capture("Keyboard fields", app: app)
        purpose.typeText("Check-in only\n")
        XCTAssertEqual(recipient.value as? String, "Hotel Nord Reservation Office")
        XCTAssertEqual(purpose.value as? String, "Check-in only")
        capture("Entered watermark", app: app)
        openCopy(app)
        capture("Latest copy", app: app)
        app.buttons["Share copy"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
        capture("System share sheet", app: app)
        let closeShare = app.buttons["header.closeButton"]
        let closable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: closeShare)
        wait(for: [closable], timeout: 10)
        closeShare.tap()
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.navigationBars["Your copy"].buttons["Close"])
        wait(for: [returned], timeout: 10)
        app.navigationBars["Your copy"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(recipient.waitForExistence(timeout: 5))
        XCTAssertEqual(recipient.value as? String, "Hotel Nord Reservation Office")
        XCTAssertEqual(purpose.value as? String, "Check-in only")
    }
}
