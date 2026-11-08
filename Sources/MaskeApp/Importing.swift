import PDFKit
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
    /// The first pages of a PDF (front and back is enough), rendered as images.
    static func images(fromPDF url: URL, maxPages: Int = 2) -> [CGImage] {
        guard let doc = PDFDocument(url: url) else { return [] }
        let count = min(doc.pageCount, maxPages)
        let images: [CGImage] = (0..<count).compactMap { i in
            guard let page = doc.page(at: i) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { return nil }
            let scale = 2200 / max(bounds.width, bounds.height)
            return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox).upright()
        }
        return images.count == count ? images : []
    }

    static func images(fromFile url: URL) -> [CGImage] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "pdf" { return images(fromPDF: url) }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data)?.upright() else { return [] }
        return [image]
    }
}

/// The system document camera: finds the edges, straightens the page, and can take front and back.
struct DocumentScanner: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void
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
            let images = (0..<min(scan.pageCount, 4)).map { scan.imageOfPage(at: $0) }
            parent.onFinish(images)
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
