import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import Maske

final class ImportingTests: XCTestCase {
    private func pdf(pages: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        var box = CGRect(x: 0, y: 0, width: 300, height: 180)
        let context = try XCTUnwrap(CGContext(consumer: try XCTUnwrap(CGDataConsumer(url: url as CFURL)), mediaBox: &box, nil))
        for index in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(gray: CGFloat(index + 1) / CGFloat(pages + 1), alpha: 1)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    func testThreePagePDFImportsEveryPage() throws {
        let url = try pdf(pages: 3)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(Importing.images(fromPDF: url).count, 3)
    }

    func testLongPDFRequiresSelectionAndPreservesDocumentOrder() throws {
        let url = try pdf(pages: 5)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(Importing.images(fromPDF: url).isEmpty, "A long PDF must never be reported as a successful shortened import")
        let source = try XCTUnwrap(ImportSource(pdf: url))
        XCTAssertEqual(source.pageCount, 5)
        let images = source.images(at: [0, 4])
        XCTAssertEqual(images.count, 2)
        XCTAssertLessThan(try XCTUnwrap(Luma(images[0])).at(100, 100), try XCTUnwrap(Luma(images[1])).at(100, 100))
        XCTAssertTrue(source.images(at: [0, 0]).isEmpty)
        XCTAssertTrue(source.images(at: [5]).isEmpty)
        XCTAssertTrue(source.images(at: Array(0..<5)).isEmpty)
    }

    func testImageIODownsamplesAndAppliesOrientation() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1200, height: 800, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let decoded = try XCTUnwrap(Importing.image(data: data as Data, maxSide: 600))
        XCTAssertEqual(decoded.width, 400)
        XCTAssertEqual(decoded.height, 600)
    }
}
