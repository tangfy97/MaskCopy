import XCTest
final class MaskEditorUITests: XCTestCase {
    func testAdjustZoomSaveAndCancel() {
        let app = XCUIApplication()
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/synthetic/passport-nor.png")
        app.launchArguments = ["-MaskeFixture", fixture.path, "-MaskeRecipient", "Hotel Nord"]
        app.launch()
        let photo = app.buttons["Photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 60))
        photo.tap()
        let handle = app.descendants(matching: .any)["mask-corner-0"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let original = handle.value as? String
        let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 18, dy: 14)))
        var changed = handle.value as? String
        XCTAssertNotEqual(original, changed)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Mask editor"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let zoom = app.sliders["Zoom"]
        XCTAssertTrue(zoom.exists)
        zoom.adjust(toNormalizedSliderPosition: 0.3)
        let canvas = app.scrollViews["mask-editor-canvas"]
        for _ in 0..<6 {
            let frame = handle.frame
            let toolbarBottom = app.buttons["Save"].frame.maxY + 30
            let visible = canvas.frame.intersection(CGRect(x: 30, y: toolbarBottom, width: app.frame.width - 60,
                                                           height: zoom.frame.minY - toolbarBottom - 30))
            let center = CGPoint(x: frame.midX, y: frame.midY)
            if visible.contains(center) { break }
            if center.x < visible.minX { canvas.swipeRight() }
            if center.x > visible.maxX { canvas.swipeLeft() }
            if center.y < visible.minY { canvas.swipeDown() }
            if center.y > visible.maxY { canvas.swipeUp() }
        }
        XCTAssertTrue(handle.isHittable)
        let zoomed = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        zoomed.press(forDuration: 0.1, thenDragTo: zoomed.withOffset(CGVector(dx: 30, dy: 24)))
        XCTAssertNotEqual(handle.value as? String, changed)
        changed = handle.value as? String
        app.buttons["Save"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.press(forDuration: 1.1)
        app.buttons["Adjust box"].tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.value as? String, changed)
        let cancelled = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        cancelled.press(forDuration: 0.1, thenDragTo: cancelled.withOffset(CGVector(dx: 15, dy: 10)))
        XCTAssertNotEqual(handle.value as? String, changed)
        app.buttons["Cancel"].tap()
        photo.press(forDuration: 1.1)
        app.buttons["Adjust box"].tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.value as? String, changed)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["Share copy"])
        wait(for: [ready], timeout: 10)
        let share = XCTAttachment(screenshot: app.screenshot())
        share.name = "New export preview"
        share.lifetime = .keepAlways
        add(share)
    }
}
