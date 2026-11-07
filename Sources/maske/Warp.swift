import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import MaskeCore
import UniformTypeIdentifiers

/// Photograph-like copies of a document: seen at an angle, turned, on a table, under uneven light,
/// saved as JPEG. Each copy records where the document went, so masks found on the copy can be
/// compared with masks found on the original.
struct WarpRecord: Codable {
    var file: String
    var source: String
    var variant: String
    /// The source image's corners in the copy (normalized, origin top left), in the order
    /// top left, top right, bottom right, bottom left of the source.
    var corners: Quad
}

enum Warp {
    struct Variant {
        let name: String
        let degrees: CGFloat   // turned clockwise
        let tilt: CGFloat      // how much narrower the far edge is
        let skew: CGFloat      // sideways lean of the far edge
    }

    static let variants = [
        Variant(name: "tilt", degrees: 3, tilt: 0.16, skew: 0.05),
        Variant(name: "rot14", degrees: -14, tilt: 0.08, skew: -0.04),
        Variant(name: "turn90", degrees: 90, tilt: 0.1, skew: 0.03),
        Variant(name: "turn180", degrees: 180, tilt: 0.06, skew: 0),
        Variant(name: "steep", degrees: 8, tilt: 0.28, skew: 0.08),
    ]

    static let context = CIContext()

    static func make(_ source: CGImage, _ v: Variant) -> (CGImage, Quad)? {
        let w = CGFloat(source.width), h = CGFloat(source.height)
        let side = max(w, h) * 1.45
        let k = 0.66 * side / max(w, h)
        let theta = v.degrees * .pi / 180
        // Corners around the centre, y down; the far (top) edge narrower and leaning.
        let half = (x: w * k / 2, y: h * k / 2)
        var pts = [CGPoint(x: -half.x * (1 - v.tilt) + half.x * v.skew, y: -half.y * (1 - v.tilt * 0.4)),
                   CGPoint(x: half.x * (1 - v.tilt) + half.x * v.skew, y: -half.y * (1 - v.tilt * 0.4)),
                   CGPoint(x: half.x, y: half.y),
                   CGPoint(x: -half.x, y: half.y)]
        pts = pts.map { p in
            CGPoint(x: side / 2 + p.x * cos(theta) - p.y * sin(theta), y: side / 2 + p.x * sin(theta) + p.y * cos(theta))
        }
        // Core Image works from the bottom left.
        func ci(_ p: CGPoint) -> CIVector { CIVector(x: p.x, y: side - p.y) }
        guard let f = CIFilter(name: "CIPerspectiveTransform") else { return nil }
        f.setValue(CIImage(cgImage: source), forKey: kCIInputImageKey)
        f.setValue(ci(pts[0]), forKey: "inputTopLeft")
        f.setValue(ci(pts[1]), forKey: "inputTopRight")
        f.setValue(ci(pts[2]), forKey: "inputBottomRight")
        f.setValue(ci(pts[3]), forKey: "inputBottomLeft")
        guard let doc = f.outputImage else { return nil }

        // A wooden-looking table: warm gradient with fine noise, and light falling off to one side.
        let extent = CGRect(x: 0, y: 0, width: side, height: side)
        let table = CIImage(color: CIColor(red: 0.42, green: 0.31, blue: 0.22)).cropped(to: extent)
        let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!.cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.08, y: 0, z: 0, w: 0),
                                                          "inputGVector": CIVector(x: 0, y: 0.06, z: 0, w: 0),
                                                          "inputBVector": CIVector(x: 0, y: 0, z: 0.05, w: 0),
                                                          "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
        let background = noise.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: table])
        var photo = doc.composited(over: background).cropped(to: extent)
        let light = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: side), "inputPoint1": CIVector(x: side, y: 0),
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 0), "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0.28),
        ])!.outputImage!.cropped(to: extent)
        photo = light.composited(over: photo).applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8]).cropped(to: extent)
        guard let out = context.createCGImage(photo, from: extent) else { return nil }
        let q = Quad(tl: pts[0], tr: pts[1], br: pts[2], bl: pts[3]).mapped { CGPoint(x: $0.x / side, y: $0.y / side) }
        return (out, q)
    }

    static func writeJPEG(_ image: CGImage, to url: URL, quality: CGFloat = 0.78) {
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    static func images(in dir: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.filter { ["png", "jpg", "jpeg"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
            .map { dir.appendingPathComponent($0) }
    }

    /// The image with outlines: green where the original's masks fall, filled red where the copy's do.
    static func overlay(_ image: CGImage, expected: [Quad], found: [Quad]) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let W = CGFloat(w), H = CGFloat(h)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
        func path(_ q: Quad) -> CGPath {
            let p = CGMutablePath()
            p.addLines(between: q.points.map { CGPoint(x: $0.x * W, y: H - $0.y * H) })
            p.closeSubpath()
            return p
        }
        ctx.setFillColor(CGColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 0.45))
        for q in found { ctx.addPath(path(q)); ctx.fillPath() }
        ctx.setStrokeColor(CGColor(srgbRed: 0.1, green: 0.85, blue: 0.2, alpha: 1))
        ctx.setLineWidth(max(2, W / 500))
        for q in expected { ctx.addPath(path(q)); ctx.strokePath() }
        return ctx.makeImage()
    }
}
