import SwiftUI
import UIKit

/// One sharing session: the pages, what to hide on them, and who the copy is for.
/// Lives only in memory and is cleared when the session ends.
@MainActor
final class Session: ObservableObject {
    struct Page: Identifiable {
        let id = UUID()
        let image: CGImage
        let kind: DocumentKind
        let country: Country?
        var findings: [Finding] { didSet { revision = UUID() } }
        private(set) var revision = UUID()
    }

    enum Step: Hashable { case review, share, supported }

    @Published var path: [Step] = []
    @Published var pages: [Page] = []
    enum Activity: Equatable { case idle, preparing, reading }
    @Published private(set) var activity = Activity.idle
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var completedPages = 0
    @Published private(set) var totalPages = 0
    @Published var importFailed = false
    @Published var recipient = ""
    @Published var purpose = ""

    private var generation = UUID()
    private var importTask: Task<Void, Never>?
    private var analysisTask: Task<[(CGImage, PageAnalysis?)], Never>?
    private let read: @Sendable (CGImage) -> (CGImage, PageAnalysis?)

    init(read: (@Sendable (CGImage) -> (CGImage, PageAnalysis?))? = nil) {
        Exporter.clear()
        self.read = read ?? { image in
            do {
                let (document, analysis) = try Analyzer().analyze(photo: image)
                return (document.image, analysis)
            } catch {
                return (image, nil)
            }
        }
    }

    var analyzing: Bool { activity != .idle }
    var hasDocument: Bool { analyzing || !pages.isEmpty }
    var documentID: UUID { generation }

    var progressTitle: String {
        if activity == .preparing { return "Opening document…" }
        return totalPages > 1 ? "Reading \(min(completedPages + 1, totalPages)) of \(totalPages)…" : "Reading document…"
    }

    var kind: DocumentKind { pages.map(\.kind).first { $0 != .unknown } ?? .unknown }
    var country: Country? { pages.compactMap(\.country).first }

    var kindsPresent: [FindingKind] {
        let present = Set(pages.flatMap(\.findings).map(\.kind))
        return FindingKind.displayOrder.filter(present.contains)
    }

    func start(with images: [CGImage]) {
        clear()
        guard !images.isEmpty else { failImport(); return }
        path = [.review]
        beginReading(images, ticket: generation)
    }

    func importImages(using load: @escaping @Sendable () async -> [CGImage]) {
        clear()
        let ticket = generation
        activity = .preparing
        path = [.review]
        importTask = Task {
            let images = await load()
            guard !Task.isCancelled, generation == ticket else { return }
            guard !images.isEmpty else { failImport(); return }
            beginReading(images, ticket: ticket)
        }
    }

    private func beginReading(_ images: [CGImage], ticket: UUID) {
        activity = .reading
        previewImage = images.first
        totalPages = images.count
        let read = self.read
        let work = Task.detached(priority: .userInitiated) {
            var results: [(CGImage, PageAnalysis?)] = []
            for image in images {
                guard !Task.isCancelled else { return results }
                results.append(read(image))
                let count = results.count
                await MainActor.run {
                    if self.generation == ticket { self.completedPages = count }
                }
            }
            return results
        }
        analysisTask = work
        Task {
            let results = await work.value
            guard !work.isCancelled, generation == ticket else { return }
            pages = results.map { image, a in
                Page(image: image, kind: a?.kind ?? .unknown, country: a?.country, findings: a?.findings ?? [])
            }
            previewImage = nil
            activity = .idle
            analysisTask = nil
        }
    }

    private func failImport() {
        finish()
        importFailed = true
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
        generation = UUID()
        importTask?.cancel()
        analysisTask?.cancel()
        importTask = nil
        analysisTask = nil
        activity = .idle
        previewImage = nil
        completedPages = 0
        totalPages = 0
        importFailed = false
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

/// Writes temporary copies for the share sheet and deletes them when the session ends.
enum Exporter {
    static var directory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Copies", isDirectory: true) }

    static func preview(_ pages: [Session.Page], recipient: String, purpose: String) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        let watermark = Watermark(recipient: recipient, purpose: purpose)
        return Renderer.render(pages: pages.map { ($0.image, $0.findings) }, watermark: watermark)
    }

    /// Only an explicit Share action writes a file. Each attempt owns its directory,
    /// so cancelling an old attempt cannot remove a newer copy.
    static func writeCopy(_ image: CGImage, recipient: String) -> URL? {
        guard !Task.isCancelled, let data = Renderer.jpegData(image) else { return nil }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let who = recipient.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        let url = folder.appendingPathComponent("ID copy for \(who.isEmpty ? "recipient" : who) \(f.string(from: Date())).jpg")
        do {
            guard !Task.isCancelled else { return nil }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            discard(url)
            return nil
        }
        guard !Task.isCancelled else { discard(url); return nil }
        return url
    }

    static func discard(_ file: URL) {
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}
