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

    /// A synthetic payslip: not an identity document, so the free app refuses it.
    /// A synthetic bank statement with transaction rows and a salary row.
    static var statementPath: String {
        URL(fileURLWithPath: passportPath).deletingLastPathComponent().appendingPathComponent("statement-gbr.png").path
    }

    static var payslipPath: String {
        URL(fileURLWithPath: passportPath).deletingLastPathComponent().appendingPathComponent("payslip-deu.png").path
    }
}

extension XCUIApplication {
    /// Every journey test starts after the first-run tour; TourUITests covers the tour itself.
    func launchWithoutTour() {
        launchArguments += ["-MaskeTourSeen", "99"]
        launch()
    }
}
