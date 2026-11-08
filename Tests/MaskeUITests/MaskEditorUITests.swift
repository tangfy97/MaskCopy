import XCTest
final class MaskEditorUITests: XCTestCase {
    func testMovingMaskDirectlyOnReview() {
        let app = XCUIApplication()
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/synthetic/passport-nor.png")
        app.launchArguments = ["-MaskeFixture", fixture.path]
        app.launch()
        let photo = app.buttons["mask-photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 60))
        photo.tap()
        let handle = app.buttons["mask-corner-0"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let original = handle.value as? String
        let bodySize = app.buttons["mask-body"].frame.size
        app.buttons["Cancel"].tap()
        let canvas = app.otherElements["page-canvas"].firstMatch
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.4))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 22, dy: 12)))
        photo.tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(handle.value as? String, original)
        XCTAssertEqual(app.buttons["mask-body"].frame.width, bodySize.width, accuracy: 1)
        XCTAssertEqual(app.buttons["mask-body"].frame.height, bodySize.height, accuracy: 1)
        let moved = handle.value as? String
        app.buttons["Save"].tap()
        photo.tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.value as? String, moved)
        app.buttons["Cancel"].tap()
    }

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
        let body = app.buttons["mask-body"]
        XCTAssertTrue(body.exists)
        let beforeMove = body.value as? String
        let move = body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let boxSize = body.frame.size
        move.press(forDuration: 0.1, thenDragTo: move.withOffset(CGVector(dx: 20, dy: 12)))
        XCTAssertNotEqual(body.value as? String, beforeMove)
        XCTAssertEqual(body.frame.width, boxSize.width, accuracy: 1)
        XCTAssertEqual(body.frame.height, boxSize.height, accuracy: 1)
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
        let canvas = app.scrollViews["mask-editor-canvas"]
        let initialZoom = zoom.value as? String
        canvas.doubleTap()
        XCTAssertNotEqual(zoom.value as? String, initialZoom)
        canvas.doubleTap()
        canvas.pinch(withScale: 2, velocity: 1)
        XCTAssertNotEqual(zoom.value as? String, initialZoom)
        zoom.adjust(toNormalizedSliderPosition: 0.3)
        XCTAssertEqual(handle.frame.width, 44, accuracy: 1, "Corner targets must keep their screen size while zooming")
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
        app.buttons["Preview copy"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["Share copy"])
        wait(for: [ready], timeout: 10)
        let share = XCTAttachment(screenshot: app.screenshot())
        share.name = "New export preview"
        share.lifetime = .keepAlways
        add(share)
    }
}
