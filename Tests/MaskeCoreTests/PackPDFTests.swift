import CoreGraphics
import PDFKit
import XCTest
@testable import MaskeCore

final class PackPDFTests: XCTestCase {
    private func image(width: Int, height: Int, gray: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: gray, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    /// Several copies make one PDF page each, in order, with nothing but their images.
    func testOnePagePerCopy() throws {
        let copies = [image(width: 400, height: 250, gray: 0.2), image(width: 300, height: 600, gray: 0.8)]
        let data = try XCTUnwrap(Renderer.pdfData(copies))
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(pdf.pageCount, 2)
        let first = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        let second = try XCTUnwrap(pdf.page(at: 1)).bounds(for: .mediaBox)
        XCTAssertEqual(first.width / first.height, 400.0 / 250.0, accuracy: 0.01)
        XCTAssertEqual(second.width / second.height, 300.0 / 600.0, accuracy: 0.01)
        XCTAssertTrue((pdf.string ?? "").isEmpty, "no text layer")
        XCTAssertNil(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute])
    }
}
