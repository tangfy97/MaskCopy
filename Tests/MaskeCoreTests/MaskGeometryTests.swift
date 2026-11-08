import CoreGraphics
import XCTest
@testable import MaskeCore

final class MaskGeometryTests: XCTestCase {
    func testPortraitSearchStopsBeforeAFieldBelowThePhoto() {
        let face = CGRect(x: 0.08, y: 0.37, width: 0.17, height: 0.28)
        let categories = TextLine(text: "9. A BE DE S T", quad: Quad(CGRect(x: 0.03, y: 0.78, width: 0.25, height: 0.04)), candidate: nil)
        let page = Page(lines: [categories], aspect: 1.59)
        let search = page.photoEstimate(around: face).insetBy(dx: 0, dy: -face.height * 0.35).clampedToUnit()
        let bounds = page.photoBounds(around: face, within: search)
        XCTAssertTrue(bounds.contains(face))
        XCTAssertEqual(bounds.maxY, categories.box.minY - face.height * 0.03, accuracy: 1e-8)
    }

    func testWarpRejectsInvalidGeometryBeforeRendering() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8,
                                             bytesPerRow: 4, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let full = Quad(CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertNil(Rectifier.warp(image, to: Quad(tl: full.tl, tr: full.br, br: full.tr, bl: full.bl), maxSide: 100))
        XCTAssertNil(Rectifier.warp(image, to: full, maxSide: 0))
    }

    func testProjectiveInkFitKeepsBothEndsOfTaperedText() throws {
        let width = 600, height = 300
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(gray: 0, alpha: 1)
        let frame = Quad(tl: CGPoint(x: 0.1, y: 0.3), tr: CGPoint(x: 0.9, y: 0.2),
                         br: CGPoint(x: 0.88, y: 0.65), bl: CGPoint(x: 0.12, y: 0.5))
        let transform = Homography(unitSquareTo: frame)
        let glyphs = (0..<10).map { index in
            transform.apply(Quad(CGRect(x: 0.025 + CGFloat(index) * 0.095, y: 0.2, width: 0.055, height: 0.6)))
        }
        for glyph in glyphs {
            let path = CGMutablePath()
            path.addLines(between: glyph.points.map { CGPoint(x: $0.x * CGFloat(width), y: $0.y * CGFloat(height)) })
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
        let image = try XCTUnwrap(context.makeImage())
        let mask = try XCTUnwrap(InkFit.fit(frame, in: try XCTUnwrap(Luma(image))))
        for glyph in glyphs {
            for corner in glyph.points { XCTAssertTrue(mask.contains(corner), "Tapered glyph corner escaped: \(corner)") }
        }
        XCTAssertGreaterThan(dist(mask.tr, mask.br), dist(mask.tl, mask.bl) * 1.6)
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0.3, y: 0.7)] {
            let restored = try XCTUnwrap(transform.unapply(transform.apply(point)))
            XCTAssertEqual(restored.x, point.x, accuracy: 1e-8)
            XCTAssertEqual(restored.y, point.y, accuracy: 1e-8)
        }
        XCTAssertFalse(Quad(tl: frame.tl, tr: frame.br, br: frame.tr, bl: frame.bl).isConvex)
    }

    func testOpaqueMaskReplacesAllSourcePixelsAndFooterWraps() throws {
        func page(_ level: CGFloat) throws -> CGImage {
            let context = try XCTUnwrap(CGContext(data: nil, width: 400, height: 250, bitsPerComponent: 8,
                                                 bytesPerRow: 400, space: CGColorSpaceCreateDeviceGray(),
                                                 bitmapInfo: CGImageAlphaInfo.none.rawValue))
            context.setFillColor(gray: level, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 250))
            return try XCTUnwrap(context.makeImage())
        }
        let white = try page(1), black = try page(0)
        let masks = [Finding(kind: .photo, rect: CGRect(x: 0, y: 0, width: 1, height: 1))]
        let a = try XCTUnwrap(Renderer.render(pages: [(white, masks)], watermark: nil))
        let b = try XCTUnwrap(Renderer.render(pages: [(black, masks)], watermark: nil))
        XCTAssertEqual(try XCTUnwrap(a.dataProvider?.data) as Data, try XCTUnwrap(b.dataProvider?.data) as Data)
        let short = try XCTUnwrap(Renderer.render(pages: [(white, [])], watermark: Watermark(recipient: "Hotel Nord")))
        let long = try XCTUnwrap(Renderer.render(pages: [(white, [])], watermark: Watermark(
            recipient: String(repeating: "A long recipient name ", count: 8),
            purpose: "Only for the reservation, with a purpose that must be kept in full")))
        XCTAssertEqual(short.width, white.width)
        XCTAssertGreaterThan(short.height, white.height)
        XCTAssertGreaterThan(long.height, short.height)
        let luma = try XCTUnwrap(Luma(long))
        XCTAssertTrue((250..<luma.height - 16).contains { y in
            (16..<luma.width - 16).contains { x in luma.at(CGFloat(x), CGFloat(y)) < 140 }
        })
    }

    func testPortraitEstimateStopsAtAdjacentFieldColumn() {
        let face = CGRect(x: 0.08, y: 0.39, width: 0.28, height: 0.42)
        let fields = [
            CGRect(x: 0.438, y: 0.44, width: 0.20, height: 0.035),
            CGRect(x: 0.439, y: 0.58, width: 0.32, height: 0.034),
            CGRect(x: 0.435, y: 0.68, width: 0.18, height: 0.034),
            CGRect(x: 0.21, y: 0.51, width: 0.13, height: 0.040) // print over the portrait
        ]
        for mirrored in [false, true] {
            func layout(_ r: CGRect) -> CGRect {
                mirrored ? CGRect(x: 1 - r.maxX, y: r.minY, width: r.width, height: r.height) : r
            }
            let lines = fields.map { TextLine(text: "FIELD", quad: Quad(layout($0)), candidate: nil) }
            let page = Page(lines: lines, aspect: 1.63)
            let locatedFace = layout(face)
            let estimate = page.photoEstimate(around: locatedFace)
            let mask = page.photoBounds(around: locatedFace, within: estimate)
            XCTAssertTrue(mask.contains(locatedFace))
            XCTAssertEqual(mask.height, estimate.height, accuracy: 0.0001)
            XCTAssertEqual(mirrored ? mask.minX : mask.maxX, mirrored ? 0.565 : 0.435, accuracy: 0.0001)
        }
    }

    func testOneAdjacentLineDoesNotCropPortraitEstimate() {
        let face = CGRect(x: 0.08, y: 0.39, width: 0.28, height: 0.42)
        let stamp = TextLine(text: "SPECIMEN", quad: Quad(CGRect(x: 0.40, y: 0.54, width: 0.2, height: 0.04)), candidate: nil)
        let page = Page(lines: [stamp], aspect: 1.63)
        let estimate = page.photoEstimate(around: face)
        XCTAssertEqual(page.photoBounds(around: face, within: estimate), estimate)
    }

    func testPassportRowsIncludeSplitFillersAndSecondLineWithoutFillers() {
        func line(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) -> TextLine {
            TextLine(text: text, quad: Quad(CGRect(x: x, y: y, width: width, height: 0.04)), candidate: nil)
        }
        let name = line("PKNLDDE<VRIES<<ANNA" + String(repeating: "く", count: 19) + "、",
                        x: 0.04, y: 0.80, width: 0.77)
        let fillers = line("くくくくくく", x: 0.82, y: 0.80, width: 0.12)
        let numbers = line("AB12345678NLD8507158F3401011ABCDEFGHIJKLMNO0",
                           x: 0.04, y: 0.88, width: 0.90)
        let rows = MRZReader.passportRows(in: [fillers, numbers, name])
        XCTAssertEqual(rows.map(\.text), [name.text + fillers.text, numbers.text])
        XCTAssertEqual(rows.first?.quad.tr, fillers.quad.tr)
        XCTAssertTrue(MRZReader.passportRows(in: [fillers, numbers]).isEmpty)
    }

    func testDutchLicenceMRZUsesNumberAfterVersion() throws {
        let text = "D1NLD11234567890AG5R98GT5IN2L4" // Published eDL reading-manual example.
        let line = TextLine(text: text, quad: Quad(CGRect(x: 0.04, y: 0.86, width: 0.91, height: 0.06)), candidate: nil)
        let result = MRZReader.find(in: [line])
        let mrz = try XCTUnwrap(result.0)
        XCTAssertEqual(mrz.format, .licence)
        XCTAssertEqual(mrz.issuingState, "NLD")
        XCTAssertEqual(mrz.documentNumber, "1234567890")
        XCTAssertTrue(mrz.checksumsValid)
    }

    func testNorwegianPersonalNumberAfterExpiryOnSameOCRLine() throws {
        let text = "4b. 28.02.2038 Ad. 15078540000"
        let line = TextLine(text: text, quad: Quad(CGRect(x: 0.25, y: 0.4, width: 0.5, height: 0.05)), candidate: nil)
        var page = Page(lines: [line], aspect: 1.59)
        page.country = "NO"
        page.findFieldCodes(numbered: true)
        let mask = try XCTUnwrap(page.findings.first)
        XCTAssertEqual(mask.kind, .personalNumber)
        XCTAssertGreaterThan(mask.rect.minX, line.box.midX)
    }

    func testHalfTurnKeepsSourceCoordinatesInSyncWithPixels() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 8, height: 4, bitsPerComponent: 8,
                                             bytesPerRow: 8, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = try XCTUnwrap(context.makeImage())
        let corners = Quad(CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6))
        let document = DocumentImage(image: image, corners: corners, fillsFrame: true, quarterTurns: 2, quickLines: 4)
        let corrected = try XCTUnwrap(Rectifier.halfTurn(document))
        let luma = try XCTUnwrap(Luma(corrected.image))
        XCTAssertEqual(luma.at(7, 0), 0)
        XCTAssertEqual(luma.at(0, 3), 255)
        XCTAssertEqual(corrected.corners.tl, corners.br)
        XCTAssertEqual(corrected.corners.br, corners.tl)
        XCTAssertEqual(corrected.quarterTurns, 0)
        XCTAssertEqual(corrected.quickLines, 4)
    }

    func testInkFitLevelsSlightlyTiltedOCRBoxWithoutCuttingEndInk() throws {
        let width = 260, height = 120
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 0, alpha: 1)
        for x in stride(from: 40, through: 202, by: 18) {
            context.fill(CGRect(x: x, y: 52, width: 10, height: 16))
        }
        let luma = try XCTUnwrap(Luma(try XCTUnwrap(context.makeImage())))
        let a: CGFloat = 3 * .pi / 180
        let estimate = Quad(CGRect(x: -88, y: -12, width: 176, height: 24)).mapped {
            CGPoint(x: (126 + $0.x * cos(a) - $0.y * sin(a)) / CGFloat(width),
                    y: (60 + $0.x * sin(a) + $0.y * cos(a)) / CGFloat(height))
        }
        let mask = try XCTUnwrap(InkFit.fit(estimate, in: luma))
        XCTAssertEqual(mask.tl.y, mask.tr.y, accuracy: 1 / CGFloat(height))
        XCTAssertTrue(mask.contains(CGPoint(x: 40 / CGFloat(width), y: 52 / CGFloat(height))))
        XCTAssertTrue(mask.contains(CGPoint(x: 211 / CGFloat(width), y: 67 / CGFloat(height))))

        // A dark stroke from the background runs into the adjacent rows.
        context.fill(CGRect(x: 116, y: 28, width: 5, height: 64))
        let patterned = try XCTUnwrap(Luma(try XCTUnwrap(context.makeImage())))
        XCTAssertNil(InkFit.fit(estimate, in: patterned))
    }
}
