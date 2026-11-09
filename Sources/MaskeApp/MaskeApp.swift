import SwiftUI

@main
struct MaskCopyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var session = Session()

    var body: some View {
        NavigationStack(path: $session.path) {
            HomeView()
                .navigationDestination(for: Session.Step.self) { step in
                    switch step {
                    case .review: ReviewView()
                    case .share: ShareView()
                    case .preview: ReadyCopyView()
                    case .supported: SupportedView()
                    }
                }
        }
        .environmentObject(session)
        .tint(.fjord)
        // Hide the document in the app switcher.
        .privacyShield(session.hasDocument)
        .onChange(of: session.path) { old, new in
            if old.contains(.review), !new.contains(.review), session.hasDocument { session.clear() }
        }
        .alert("Couldn’t open document", isPresented: Binding(get: { session.importFailed }, set: { shown in
            // The system may dismiss an alert while updating its presenter.
            Task { @MainActor in session.importFailed = shown }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose another photo or file.")
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
        let images = paths.split(separator: ",").compactMap { path -> CGImage? in
            let url = path.hasPrefix("/") ? URL(fileURLWithPath: String(path))
                : URL.cachesDirectory.appendingPathComponent(String(path))
            return UIImage(contentsOfFile: url.path)?.upright()
        }
        session.start(with: images)
        if let r = defaults.string(forKey: "MaskeRecipient") { session.recipient = r }
        if let p = defaults.string(forKey: "MaskePurpose") { session.purpose = p }
        if defaults.string(forKey: "MaskeStep") == "share" { session.path = [.review, .share] }
    }
}
#endif
