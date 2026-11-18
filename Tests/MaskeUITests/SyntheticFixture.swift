import Foundation
import XCTest

enum SyntheticFixture {
    static var passportPath: String {
        #if targetEnvironment(simulator)
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/synthetic/passport-nor.png").path
        #else
        "MaskCopyFixtures/passport-nor.png"
        #endif
    }
}

extension XCUIApplication {
    /// Every journey test starts after the first-run tour; TourUITests covers the tour itself.
    func launchWithoutTour() {
        launchArguments += ["-MaskeTourSeen", "99"]
        launch()
    }
}
