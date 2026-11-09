import Foundation

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
