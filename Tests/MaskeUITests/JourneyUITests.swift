import XCTest
import CoreGraphics

final class JourneyUITests: XCTestCase {
    private var fixture: String {
        SyntheticFixture.passportPath
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
    func testVisibleMaskControlsAndAdding() {
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
        XCTAssertTrue(app.navigationBars["Adjust box"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["mask-custom"].exists)
        app.buttons["Add box"].tap()
        XCTAssertTrue(app.navigationBars["Adjust box"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["mask-custom"].firstMatch.exists)
    }

    func testWatermarkPositionSaveCancelAndReset() {
        let app = documentApp()
        app.buttons["Continue"].tap()
        openCopy(app)
        app.buttons["Move watermark"].tap()
        let position = app.descendants(matching: .any)["watermark-position"].firstMatch
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        let original = position.value as? String
        capture("Watermark position", app: app)
        position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertNotEqual(position.value as? String, original)
        capture("Moved watermark", app: app)
        app.buttons["Cancel"].tap()
        app.buttons["Move watermark"].tap()
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        XCTAssertEqual(position.value as? String, original)
        position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        let changed = position.value as? String
        app.buttons["Save"].tap()
        let fresh = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["Share copy"])
        wait(for: [fresh], timeout: 10)
        capture("Positioned final copy", app: app)
        app.buttons["Move watermark"].tap()
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        XCTAssertEqual(position.value as? String, changed)
        app.buttons["Reset"].tap()
        XCTAssertEqual(position.value as? String, original)
        app.buttons["Save"].tap()
    }

    func testLongPDFPageSelectionLimitAndCancel() throws {
        #if targetEnvironment(simulator)
        let url = URL(fileURLWithPath: "/tmp/maskcopy-five-page-ui-test.pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var bounds = CGRect(x: 0, y: 0, width: 300, height: 180)
        let context = try XCTUnwrap(CGContext(consumer: try XCTUnwrap(CGDataConsumer(url: url as CFURL)), mediaBox: &bounds, nil))
        for index in 0..<5 {
            context.beginPDFPage(nil)
            context.setFillColor(gray: CGFloat(index + 1) / 6, alpha: 1)
            context.fill(bounds)
            context.endPDFPage()
        }
        context.closePDF()
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeImportPDF", url.path]
        app.launch()
        XCTAssertTrue(app.collectionViews["page-selection"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["import-selected-pages"].isEnabled)
        for index in 1...4 { app.buttons["import-page-\(index)"].tap() }
        let fifth = app.buttons["import-page-5"]
        if !fifth.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertFalse(fifth.isEnabled)
        capture("Explicit page limit", app: app)
        app.buttons["import-page-4"].tap()
        XCTAssertTrue(fifth.isEnabled)
        fifth.tap()
        XCTAssertEqual(fifth.value as? String, "Selected")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Choose photos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Hide details"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["import-page-1"].waitForExistence(timeout: 10))
        app.buttons["import-page-1"].tap()
        if !fifth.isHittable { app.collectionViews.firstMatch.swipeUp() }
        fifth.tap()
        app.buttons["import-selected-pages"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 60))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "page-canvas").count, 2)
        capture("Only selected pages imported", app: app)
        #endif
    }

    func testLongCJKWatermarkLayout() {
        let app = documentApp(recipient: "北欧酒店预订与入住登记服务中心", purpose: "仅供入住核验使用，不作其他用途")
        app.buttons["Continue"].tap()
        openCopy(app)
        capture("CJK final copy", app: app)
        app.buttons["Move watermark"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["watermark-position"].firstMatch.waitForExistence(timeout: 10))
        capture("CJK watermark placement", app: app)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Share copy"].isEnabled)
    }

    func testMultiPageMaskAndWatermarkTargeting() {
        let app = XCUIApplication()
        app.launchArguments = ["-MaskeFixture", fixture + "," + fixture, "-MaskeRecipient", "Hotel Nord"]
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 90))
        app.buttons["Add box"].tap()
        app.buttons["Page 2"].tap()
        XCTAssertTrue(app.navigationBars["Adjust box"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "mask-custom").count, 1)
        app.buttons["Continue"].tap()
        openCopy(app)
        app.buttons["Move watermark"].tap()
        let position = app.descendants(matching: .any)["watermark-position"].firstMatch
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        let original = position.value as? String
        app.segmentedControls.buttons["Page 2"].tap()
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        let second = position.value as? String
        XCTAssertNotEqual(second, original)
        app.segmentedControls.buttons["Page 1"].tap()
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        XCTAssertEqual(position.value as? String, original)
        app.segmentedControls.buttons["Page 2"].tap()
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        XCTAssertEqual(position.value as? String, second)
        capture("Independent page watermark", app: app)
        app.buttons["Save"].tap()
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
