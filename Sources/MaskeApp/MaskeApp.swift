import SwiftUI

@main
struct MaskeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var session = Session()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $session.path) {
            HomeView()
                .navigationDestination(for: Session.Step.self) { step in
                    switch step {
                    case .review: ReviewView()
                    case .share: ShareView()
                    case .supported: SupportedView()
                    }
                }
        }
        .environmentObject(session)
        .tint(.fjord)
        // Hide the document in the app switcher.
        .overlay {
            if scenePhase != .active && !session.pages.isEmpty {
                ZStack {
                    Color.paper.ignoresSafeArea()
                    Mark(size: 72)
                }
            }
        }
        #if DEBUG
        .task { DebugLaunch.run(session) }
        #endif
    }
}

#if DEBUG
/// Launch arguments for screenshots and testing in the simulator, which has no camera:
/// `-MaskeFixture /path/a.png,/path/b.png -MaskeRecipient "Hotel Nord" -MaskeStep share`
enum DebugLaunch {
    @MainActor
    static func run(_ session: Session) {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "MaskeStep") == "supported" { session.path = [.supported]; return }
        guard let paths = defaults.string(forKey: "MaskeFixture") else { return }
        let images = paths.split(separator: ",").compactMap { UIImage(contentsOfFile: String($0))?.upright() }
        session.start(with: images)
        if let r = defaults.string(forKey: "MaskeRecipient") { session.recipient = r }
        if let p = defaults.string(forKey: "MaskePurpose") { session.purpose = p }
        if defaults.string(forKey: "MaskeStep") == "share" { session.path = [.review, .share] }
    }
}
#endif
