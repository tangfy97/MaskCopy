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
        var watermarkPosition = CGPoint(x: 0.5, y: 0.5) { didSet { revision = UUID() } }
        private(set) var revision = UUID()
    }

    enum Step: Hashable { case review, share, preview, supported }

    @Published var path: [Step] = []
    @Published var pages: [Page] = [] { didSet { copy = nil; copyStamp = nil } }
    @Published private(set) var copy: CGImage?
    @Published private(set) var copyDate = Date()
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
    private var copyTask: Task<CGImage?, Never>?
    private struct CopyStamp: Equatable {
        let document: UUID
        let revisions: [UUID]
        let recipient: String
        let purpose: String
    }
    private var copyStamp: CopyStamp?
    private let read: @Sendable (CGImage) -> (CGImage, PageAnalysis?)
    private let render: @Sendable ([Page], Watermark) -> CGImage?

    init(render: (@Sendable ([Page], Watermark) -> CGImage?)? = nil,
         read: (@Sendable (CGImage) -> (CGImage, PageAnalysis?))? = nil) {
        Exporter.clearLater()
        self.render = render ?? { pages, watermark in
            Renderer.render(pages: pages.map { ($0.image, $0.findings) }, watermark: watermark, positions: pages.map(\.watermarkPosition))
        }
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
        guard !images.isEmpty, images.count <= Importing.maximumPages else { failImport(); return }
        withAnimation(FlowMotion.navigation) { path = [.review] }
        beginReading(images, ticket: generation)
    }

    func importImages(using load: @escaping @Sendable () async -> [CGImage]) {
        clear()
        let ticket = generation
        activity = .preparing
        withAnimation(FlowMotion.navigation) { path = [.review] }
        importTask = Task {
            let images = await load()
            guard !Task.isCancelled, generation == ticket else { return }
            guard !images.isEmpty, images.count <= Importing.maximumPages else { failImport(); return }
            beginReading(images, ticket: ticket)
        }
    }

    private func beginReading(_ images: [CGImage], ticket: UUID) {
        activity = .reading
        previewImage = images.first
        totalPages = images.count
        let read = self.read
        let cancellation = AnalysisCancellation()
        let work = Task.detached(priority: .userInitiated) {
            await withTaskCancellationHandler(operation: {
                await AnalysisWork.$cancellation.withValue(cancellation) {
                    var results: [(CGImage, PageAnalysis?)] = []
                    for image in images {
                        guard !Task.isCancelled else { return results }
                        let result = read(image)
                        guard !Task.isCancelled else { return results }
                        results.append(result)
                        let count = results.count
                        await MainActor.run {
                            if self.generation == ticket { self.completedPages = count }
                        }
                    }
                    return results
                }
            }, onCancel: { cancellation.cancel() })
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

    /// Render once after editing, never while typing or on a navigation frame.
    func prepareCopy(recipient: String, purpose: String) async -> Bool {
        let recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty, !pages.isEmpty else { return false }
        let stamp = CopyStamp(document: generation, revisions: pages.map(\.revision), recipient: recipient, purpose: purpose)
        self.recipient = recipient
        self.purpose = purpose
        if copyStamp == stamp, copy != nil { return true }
        copyTask?.cancel()
        let snapshot = pages
        let date = copyDate
        let render = self.render
        let work = Task.detached(priority: .userInitiated) {
            render(snapshot, Watermark(recipient: recipient, purpose: purpose, date: date))
        }
        copyTask = work
        let image = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
        guard !Task.isCancelled, !work.isCancelled, generation == stamp.document,
              pages.map(\.revision) == stamp.revisions, let image else { return false }
        copy = image
        copyStamp = stamp
        copyTask = nil
        return true
    }

    /// Forget everything: pages, names and the exported file.
    func clear() {
        generation = UUID()
        importTask?.cancel()
        analysisTask?.cancel()
        copyTask?.cancel()
        importTask = nil
        analysisTask = nil
        copyTask = nil
        copy = nil
        copyStamp = nil
        copyDate = Date()
        activity = .idle
        previewImage = nil
        completedPages = 0
        totalPages = 0
        importFailed = false
        pages = []
        recipient = ""
        purpose = ""
        Exporter.clearLater()
    }

    func finish() {
        clear()
        withAnimation(FlowMotion.navigation) { path = [] }
    }
}

/// Writes temporary copies for the share sheet and deletes them when the session ends.
enum Exporter {
    private static let io = DispatchQueue(label: "com.feiyangtang.Maske.export-io", qos: .utility)
    enum Format: String, CaseIterable, Sendable {
        case jpg, pdf
        var title: String { rawValue.uppercased() }
    }
    static var directory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Copies", isDirectory: true) }

    static func preview(_ pages: [Session.Page], recipient: String, purpose: String) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        let watermark = Watermark(recipient: recipient, purpose: purpose)
        return Renderer.render(pages: pages.map { ($0.image, $0.findings) }, watermark: watermark, positions: pages.map(\.watermarkPosition))
    }

    /// Only an explicit Save or Share action writes a file. Each attempt owns its directory,
    /// so cancelling an old attempt cannot remove a newer copy.
    static func writeCopy(_ image: CGImage, recipient: String, format: Format = .jpg) -> URL? {
        guard !Task.isCancelled else { return nil }
        let encoded = format == .jpg ? Renderer.jpegData(image) : Renderer.pdfData(image)
        guard let data = encoded else { return nil }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let who = String(recipient.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ").prefix(48))
        let url = folder.appendingPathComponent("ID copy for \(who.isEmpty ? "recipient" : who) \(f.string(from: Date())).\(format.rawValue)")
        guard !Task.isCancelled else { return nil }
        let written = io.sync { () -> Bool in
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                return true
            } catch {
                try? FileManager.default.removeItem(at: folder)
                return false
            }
        }
        guard written else { return nil }
        guard !Task.isCancelled else { discard(url); return nil }
        return url
    }

    static func discard(_ file: URL) {
        io.sync { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    }

    static func discardLater(_ file: URL) {
        io.async { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    }

    static func clear() {
        io.sync { try? FileManager.default.removeItem(at: directory) }
    }

    static func clearLater() {
        io.async { try? FileManager.default.removeItem(at: directory) }
    }

    /// A test/verification barrier, never used by application UI.
    static func waitForCleanup() { io.sync {} }
}
