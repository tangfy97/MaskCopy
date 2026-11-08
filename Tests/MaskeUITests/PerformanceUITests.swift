import XCTest

final class PerformanceUITests: XCTestCase {
    func testLaunchPerformance() {
        let app = XCUIApplication()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            XCTAssertTrue(app.buttons["Choose photos"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }
}
