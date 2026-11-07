import SwiftUI
import UIKit

/// One sharing session: the pages, what to hide on them, and who the copy is for.
/// Lives only in memory and is cleared as soon as the copy has been shared.
@MainActor
final class Session: ObservableObject {
    struct Page: Identifiable {
        let id = UUID()
        let image: CGImage
        let kind: DocumentKind
        let country: Country?
        var findings: [Finding]
    }

    enum Step: Hashable { case review, share, supported }

    @Published var path: [Step] = []
    @Published var pages: [Page] = []
    @Published var analyzing = false
    @Published var recipient = ""
    @Published var purpose = ""

    var kind: DocumentKind { pages.map(\.kind).first { $0 != .unknown } ?? .unknown }
    var country: Country? { pages.compactMap(\.country).first }

    var kindsPresent: [FindingKind] {
        let present = Set(pages.flatMap(\.findings).map(\.kind))
        return FindingKind.displayOrder.filter(present.contains)
    }

    func start(with images: [CGImage]) {
        guard !images.isEmpty else { return }
        clear()
        analyzing = true
        path = [.review]
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                images.map { image -> (CGImage, PageAnalysis?) in
                    do { return (image, try Analyzer().analyze(image)) } catch {
                        NSLog("Maske analysis failed: %@", String(describing: error))
                        return (image, nil)
                    }
                }
            }.value
            pages = results.map { image, a in
                Page(image: image, kind: a?.kind ?? .unknown, country: a?.country, findings: a?.findings ?? [])
            }
            analyzing = false
        }
    }

    func isOn(_ kind: FindingKind) -> Bool {
        pages.flatMap(\.findings).filter { $0.kind == kind }.allSatisfy(\.isOn)
    }

    func set(_ kind: FindingKind, on: Bool) {
        for p in pages.indices {
            for f in pages[p].findings.indices where pages[p].findings[f].kind == kind {
                pages[p].findings[f].isOn = on
            }
        }
    }

    func count(_ kind: FindingKind) -> Int {
        pages.flatMap(\.findings).filter { $0.kind == kind }.count
    }

    /// Forget everything: pages, names and the exported file.
    func clear() {
        pages = []
        recipient = ""
        purpose = ""
        Exporter.clear()
    }

    func finish() {
        clear()
        path = []
    }
}

/// Writes the shared copy to a temporary file, which is deleted when the session ends.
enum Exporter {
    static var directory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Copies", isDirectory: true) }

    static func export(_ pages: [Session.Page], recipient: String, purpose: String) -> (URL, UIImage)? {
        let watermark = Watermark(recipient: recipient, purpose: purpose)
        guard let image = Renderer.render(pages: pages.map { ($0.image, $0.findings) }, watermark: watermark),
              let data = Renderer.jpegData(image) else { return nil }
        clear()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let who = recipient.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        let url = directory.appendingPathComponent("ID copy for \(who.isEmpty ? "recipient" : who) \(f.string(from: Date())).jpg")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            return nil
        }
        return (url, UIImage(cgImage: image))
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}
