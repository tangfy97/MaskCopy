import PDFKit
import ImageIO
import SwiftUI
import UIKit
import VisionKit

extension UIImage {
    /// Upright pixels, at most `maxSide` on the long side (enough to read any card or passport).
    func upright(maxSide: CGFloat = 2800) -> CGImage? {
        let scale = min(1, maxSide / max(size.width * self.scale, size.height * self.scale))
        if imageOrientation == .up, scale == 1, let cg = cgImage { return cg }
        let target = CGSize(width: (size.width * self.scale * scale).rounded(), height: (size.height * self.scale * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }.cgImage
    }
}

enum Importing {
    static let maximumPages = 4

    /// Longer documents require explicit selection, never a shortened successful import.
    static func images(fromPDF url: URL) -> [CGImage] {
        guard let source = ImportSource(pdf: url), source.pageCount <= maximumPages else { return [] }
        return source.images(at: Array(0..<source.pageCount))
    }

    static func image(data: Data, maxSide: Int = 2800) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return thumbnail(source, maxSide: maxSide)
    }

    private static func thumbnail(_ source: CGImageSource, maxSide: Int = 2800) -> CGImage? {
        guard maxSide > 0, !Task.isCancelled else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide
        ] as CFDictionary)
    }

    static func images(fromFile url: URL) -> [CGImage] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "pdf" { return images(fromPDF: url) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = thumbnail(source) else { return [] }
        return [image]
    }
}

/// Immutable source with serialized framework access; no unredacted temporary files.
final class ImportSource: Identifiable, @unchecked Sendable {
    let id = UUID()
    let pageCount: Int
    private let pdf: PDFDocument?
    private let scan: VNDocumentCameraScan?
    private let scopedURL: URL?
    private let lock = NSLock()

    init?(pdf url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
            if scoped { url.stopAccessingSecurityScopedResource() }
            return nil
        }
        pdf = document
        scan = nil
        scopedURL = scoped ? url : nil
        pageCount = document.pageCount
    }

    init(scan: VNDocumentCameraScan) {
        self.scan = scan
        pdf = nil
        scopedURL = nil
        pageCount = scan.pageCount
    }

    deinit { scopedURL?.stopAccessingSecurityScopedResource() }

    func image(at index: Int, maxSide: Int) -> CGImage? {
        guard maxSide > 0, index >= 0, index < pageCount, !Task.isCancelled else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard !Task.isCancelled else { return nil }
        return autoreleasepool {
            if let scan { return scan.imageOfPage(at: index).upright(maxSide: CGFloat(maxSide)) }
            guard let page = pdf?.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { return nil }
            let scale = CGFloat(maxSide) / max(bounds.width, bounds.height)
            return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                .upright(maxSide: CGFloat(maxSide))
        }
    }

    func images(at indices: [Int]) -> [CGImage] {
        guard !indices.isEmpty, indices.count <= Importing.maximumPages,
              Set(indices).count == indices.count, indices.allSatisfy({ $0 >= 0 && $0 < pageCount }) else { return [] }
        var result: [CGImage] = []
        for index in indices {
            guard let image = image(at: index, maxSide: 2200), !Task.isCancelled else { return [] }
            result.append(image)
        }
        return result
    }
}

/// The system document camera: finds the edges, straightens the page, and can take front and back.
struct DocumentScanner: UIViewControllerRepresentable {
    var onFinish: (ImportSource) -> Void
    var onCancel: () -> Void
    var onError: () -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    static func dismantleUIViewController(_ controller: VNDocumentCameraViewController, coordinator: Coordinator) {
        coordinator.delivered = true
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        var delivered = false
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard !delivered else { return }
            delivered = true
            parent.onFinish(ImportSource(scan: scan))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            guard !delivered else { return }
            delivered = true
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            guard !delivered else { return }
            delivered = true
            parent.onError()
        }
    }
}
