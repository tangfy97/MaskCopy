import CoreGraphics
import CoreImage
import CoreML
import Foundation
import Vision

/// A document cut out of a photo and straightened: perspective corrected and turned upright.
public struct DocumentImage: @unchecked Sendable {
    /// The document, filling the image edge to edge when it was found.
    public let image: CGImage
    /// Where the document's corners are in the source image (normalized, origin top left), in the
    /// order of this image's top left, top right, bottom right and bottom left.
    public let corners: Quad
    /// The document's edges were found, so the image is the document and nothing else.
    public let fillsFrame: Bool
    /// Quarter turns clockwise applied to make the text upright.
    public let quarterTurns: Int
    /// How many lines of text a quick read found: a floor for the full read, which can come back short.
    public var quickLines: Int = 0

    /// A point in this image (normalized) in the source image (normalized).
    public var toSource: Homography { Homography(unitSquareTo: corners) }
}

public enum Rectifier {
    static let context = CIContext(options: [.useSoftwareRenderer: false])

    public static func straighten(_ source: CGImage, maxSide: CGFloat = 2600) -> DocumentImage {
        // One quick read of the photo each way up tells both which way up it is and where the text is.
        let (turns, text) = orientationAndText(source)
        let found = documentCorners(in: source, text: text)
        let full = Quad(CGRect(x: 0, y: 0, width: 1, height: 1))
        var corners = found ?? full
        // A document that already fills the photo (a scan, a crop) is used as it is.
        let nearFrame = zip(corners.points, full.points).allSatisfy { dist($0, $1) < 0.02 }
        if nearFrame { corners = full }
        if nearFrame && turns == 0 {
            return DocumentImage(image: source, corners: full, fillsFrame: found != nil, quarterTurns: 0, quickLines: text.count)
        }
        let turned = rotated(corners, quarterTurns: turns)
        let image = warp(source, to: turned, maxSide: maxSide) ?? source
        return DocumentImage(image: image, corners: turned, fillsFrame: found != nil, quarterTurns: turns, quickLines: text.count)
    }

    // MARK: Finding the document

    /// Reads a small copy of the photo each way up. Returns the quarter turns that make its text read
    /// best, and where that text is on the photo (centres and amount), to check candidate outlines.
    static func orientationAndText(_ image: CGImage) -> (Int, [(CGPoint, Double)]) {
        guard let small = scaled(image, maxSide: 1300) else { return (0, []) }
        let full = Quad(CGRect(x: 0, y: 0, width: 1, height: 1))
        var best = (turns: 0, score: -1.0, text: [(CGPoint, Double)]())
        for turns in 0..<4 {
            guard let turned = warp(small, to: rotated(full, quarterTurns: turns), maxSide: 1300) else { continue }
            let r = VNRecognizeTextRequest()
            r.recognitionLevel = .fast
            r.usesLanguageCorrection = true
            guard (try? VisionRunner.perform(r, on: turned)) != nil else { continue }
            let back = Homography(unitSquareTo: rotated(full, quarterTurns: turns))
            var score = 0.0
            var text: [(CGPoint, Double)] = []
            for o in r.results ?? [] {
                guard let c = o.topCandidates(1).first else { continue }
                score += readability(c.string, Double(c.confidence))
                guard c.confidence > 0.3 else { continue }
                let q = quad(o)
                text.append((back.apply(CGPoint(x: (q.tl.x + q.br.x) / 2, y: (q.tl.y + q.br.y) / 2)),
                             Double(c.string.filter { $0.isLetter || $0.isNumber }.count)))
            }
            if score > best.score { best = (turns, score, text) }
        }
        return (best.turns, best.text)
    }

    /// How much a line of quickly read text counts towards "this way up reads well".
    static func readability(_ s: String, _ conf: Double) -> Double {
        var score = conf * Double(s.filter { $0.isLetter || $0.isNumber }.count) * (conf > 0.5 ? 1 : 0.3)
        // An MRZ line only reads as such the right way up: its "<" fillers turn into ">" or noise upside down.
        let t = MRZReader.normalize(s)
        if t.count >= 25, t.filter({ $0 == "<" }).count >= 3 { score += 80 }
        return score
    }

    static func scaled(_ image: CGImage, maxSide: CGFloat) -> CGImage? {
        let s = min(1, maxSide / CGFloat(max(image.width, image.height)))
        if s == 1 { return image }
        return warp(image, to: Quad(CGRect(x: 0, y: 0, width: 1, height: 1)), maxSide: maxSide)
    }

    /// The document's corners, or nil if no convincing document edge is found. An outline counts only
    /// if most of the text on the image is inside it, so a portrait or a barcode is never taken for the document.
    static func documentCorners(in image: CGImage, text: [(CGPoint, Double)]) -> Quad? {
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        let totalText = text.map(\.1).reduce(0, +)
        func accept(_ o: VNRectangleObservation) -> Quad? {
            let q = quad(o)
            if totalText > 20 {
                let inside = text.filter { q.contains($0.0) }.map(\.1).reduce(0, +)
                guard inside / totalText > 0.8 else { return nil }
            }
            let area = q.area(aspect: aspect) / aspect
            let w = (dist(q.tl, q.tr) + dist(q.bl, q.br)) / 2 * aspect, h = (dist(q.tl, q.bl) + dist(q.tr, q.br)) / 2
            let ratio = max(w, h) / max(min(w, h), 1e-6)
            // Cards are 1.59:1, passport pages 1.42:1, a passport spread about 1.4:1 standing up.
            guard area > 0.12, ratio < 2.1 else { return nil }
            return q
        }
        let segmentation = VNDetectDocumentSegmentationRequest()
        if (try? VisionRunner.perform(segmentation, on: image)) != nil,
           let best = (segmentation.results ?? []).filter({ $0.confidence > 0.5 }).compactMap(accept).max(by: { $0.area() < $1.area() }) {
            return best
        }
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumAspectRatio = 0.45
        rectangles.maximumAspectRatio = 1
        rectangles.minimumSize = 0.3
        rectangles.quadratureTolerance = 25
        rectangles.minimumConfidence = 0.6
        rectangles.maximumObservations = 4
        if (try? VisionRunner.perform(rectangles, on: image)) != nil {
            return (rectangles.results ?? []).compactMap(accept).max { $0.area() < $1.area() }
        }
        return nil
    }

    static func quad(_ o: VNRectangleObservation) -> Quad {
        func p(_ v: CGPoint) -> CGPoint { CGPoint(x: v.x, y: 1 - v.y) }
        return Quad(tl: p(o.topLeft), tr: p(o.topRight), br: p(o.bottomRight), bl: p(o.bottomLeft))
    }

    // MARK: Orientation

    /// Corners reordered so the output is turned `k` quarter turns clockwise.
    static func rotated(_ q: Quad, quarterTurns k: Int) -> Quad {
        let p = q.points
        let r = (0..<4).map { p[($0 - k + 8) % 4] }
        return Quad(tl: r[0], tr: r[1], br: r[2], bl: r[3])
    }

    // MARK: Warping

    /// The part of `source` inside `q`, as an upright rectangle.
    static func warp(_ source: CGImage, to q: Quad, maxSide: CGFloat) -> CGImage? {
        let W = CGFloat(source.width), H = CGFloat(source.height)
        // Core Image measures from the bottom left, in pixels.
        func ci(_ p: CGPoint) -> CIVector { CIVector(x: p.x * W, y: (1 - p.y) * H) }
        let input = CIImage(cgImage: source)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(ci(q.tl), forKey: "inputTopLeft")
        filter.setValue(ci(q.tr), forKey: "inputTopRight")
        filter.setValue(ci(q.br), forKey: "inputBottomRight")
        filter.setValue(ci(q.bl), forKey: "inputBottomLeft")
        guard var out = filter.outputImage else { return nil }
        // Output size from the edge lengths, so the document keeps its proportions.
        let width = (dist(CGPoint(x: q.tl.x * W, y: q.tl.y * H), CGPoint(x: q.tr.x * W, y: q.tr.y * H))
            + dist(CGPoint(x: q.bl.x * W, y: q.bl.y * H), CGPoint(x: q.br.x * W, y: q.br.y * H))) / 2
        let height = (dist(CGPoint(x: q.tl.x * W, y: q.tl.y * H), CGPoint(x: q.bl.x * W, y: q.bl.y * H))
            + dist(CGPoint(x: q.tr.x * W, y: q.tr.y * H), CGPoint(x: q.br.x * W, y: q.br.y * H))) / 2
        let s = min(1, maxSide / max(width, height))
        let target = CGSize(width: (width * s).rounded(), height: (height * s).rounded())
        out = out.transformed(by: CGAffineTransform(translationX: -out.extent.minX, y: -out.extent.minY))
        out = out.transformed(by: CGAffineTransform(scaleX: target.width / out.extent.width, y: target.height / out.extent.height))
        return context.createCGImage(out, from: CGRect(origin: .zero, size: target), format: .RGBA8,
                                     colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    }
}

/// Runs Vision requests; on the simulator, which has no Neural Engine, on the CPU.
enum VisionRunner {
    static func perform(_ request: VNRequest, on image: CGImage) throws {
        #if targetEnvironment(simulator)
        if let devices = try? request.supportedComputeStageDevices {
            for (stage, list) in devices {
                if let cpu = list.first(where: { if case .cpu = $0 { return true } else { return false } }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        }
        #endif
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    }
}
