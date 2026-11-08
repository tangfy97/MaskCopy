import CoreGraphics
import Foundation
import Vision

/// Measures photo frames once per page, including small transparent portrait windows.
/// Full-image rectangle observations keep one coordinate system for every candidate.
struct PortraitDetector {
    let image: CGImage
    let frames: [Quad]
    private let luma: Luma?

    init(image: CGImage, sourceFrames: [Quad] = []) {
        self.image = image
        luma = Luma(image)
        frames = sourceFrames + Self.detectFrames(in: image)
    }

    static func detectFrames(in image: CGImage) -> [Quad] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 1
        request.minimumSize = 0.04
        request.minimumConfidence = 0.4
        request.maximumObservations = 32
        request.quadratureTolerance = 25
        try? VisionRunner.perform(request, on: image)
        return (request.results ?? []).map(Rectifier.quad).filter(\.isConvex)
    }

    private var aspect: CGFloat { CGFloat(image.width) / CGFloat(image.height) }

    /// A secondary passport portrait can be too small in a whole-page face read.
    func passportFaces(excluding known: [CGRect]) -> [CGRect] {
        let region = CGRect(x: 0.6, y: 0.12, width: 0.4, height: 0.60)
        let pixels = CGRect(x: region.minX * CGFloat(image.width), y: region.minY * CGFloat(image.height),
                            width: region.width * CGFloat(image.width), height: region.height * CGFloat(image.height)).integral
        guard let crop = image.cropping(to: pixels) else { return [] }
        let scale = max(1, min(3, 800 / CGFloat(crop.height)))
        guard let bitmap = CGContext(data: nil, width: Int(CGFloat(crop.width) * scale), height: Int(CGFloat(crop.height) * scale),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
        bitmap.interpolationQuality = .high
        bitmap.draw(crop, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
        guard let enlarged = bitmap.makeImage() else { return [] }
        let request = VNDetectFaceRectanglesRequest()
        guard (try? VisionRunner.perform(request, on: enlarged)) != nil else { return [] }
        return (request.results ?? []).filter { $0.confidence >= 0.6 }.map {
            let face = $0.boundingBox.flippedVertically
            return CGRect(x: (pixels.minX + face.minX * pixels.width) / CGFloat(image.width),
                          y: (pixels.minY + face.minY * pixels.height) / CGFloat(image.height),
                          width: face.width * pixels.width / CGFloat(image.width),
                          height: face.height * pixels.height / CGFloat(image.height))
        }.filter { face in !known.contains { iou($0, face) > 0.25 } }
    }

    func frame(near estimate: Quad, face: CGRect?, bounds: CGRect?) -> Quad? {
        let est = estimate.boundingRect
        let candidates = frames.filter { quad in
            guard quad.isConvex else { return false }
            let box = quad.boundingRect
            let ratio = box.width * aspect / box.height
            guard (0.5...1.1).contains(ratio) else { return false }
            if let face {
                let pixels = quad.mapped { CGPoint(x: $0.x * CGFloat(image.width), y: $0.y * CGFloat(image.height)) }
                let taper = dist(pixels.tl, pixels.tr) / dist(pixels.bl, pixels.br)
                let core = Quad(face.insetBy(dx: face.width * 0.04, dy: face.height * 0.04))
                guard (0.85...1.18).contains(taper), core.points.allSatisfy({ quad.contains($0) }),
                      box.minY < face.minY - face.height * 0.1,
                      box.maxY > face.maxY + face.height * 0.05,
                      box.area < face.area * 6 else { return false }
                if let bounds {
                    let tolerance = 2 / CGFloat(image.width)
                    guard box.minX >= bounds.minX - tolerance, box.maxX <= bounds.maxX + tolerance else { return false }
                }
                return true
            }
            return box.area > est.area * 0.45 && box.area < est.area * 1.8
                && box.intersectionArea(est) > box.area * 0.7
        }
        // Prefer the smallest verified frame that contains the face over an expanded estimate.
        return candidates.min { a, b in
            if face != nil { return a.area() < b.area() }
            return abs(a.area() - est.area) < abs(b.area() - est.area)
        }?.expanded(by: 0.01, aspect: aspect)
    }

    /// Borderless portraits have no frame. Follow substantial dark regions connected to
    /// the detected face, suppressing fine security print, to bound hair and shoulders.
    func borderlessBounds(face: CGRect, within bounds: CGRect, text: [CGRect]) -> CGRect? {
        // A light neck or collar can disconnect the shoulders from the face. Seed the
        // body too, but do not seed nearby printed fields or security text below it.
        let body = CGRect(x: face.minX - face.width * 0.2, y: face.minY,
                          width: face.width * 1.4, height: face.height * 2.1).intersection(bounds)
        guard let result = darkBounds(seed: body, within: bounds, excluding: text,
                                      margin: max(5, face.height * CGFloat(image.height) * 0.015),
                                      ceiling: face.height < 0.2 ? 170 : 150, monochromeFace: face),
              result.contains(face.insetBy(dx: face.width * 0.04, dy: face.height * 0.04)),
              result.minY < face.minY - face.height * 0.1,
              result.maxY > face.maxY + face.height * 0.05,
              result.area < bounds.area * 0.95 else { return nil }
        return result
    }

    private func darkBounds(seed: CGRect, within bounds: CGRect, excluding text: [CGRect] = [], margin: CGFloat = 1,
                            ceiling: Int = 150, monochromeFace: CGRect? = nil) -> CGRect? {
        guard let luma else { return nil }
        let step = max(1, bounds.height * CGFloat(luma.height) / 360)
        let width = Int(bounds.width * CGFloat(luma.width) / step)
        let height = Int(bounds.height * CGFloat(luma.height) / step)
        guard width > 8, height > 8 else { return nil }
        var values = [UInt8](repeating: 255, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let px = bounds.minX * CGFloat(luma.width) + CGFloat(x) * step
                let py = bounds.minY * CGFloat(luma.height) + CGFloat(y) * step
                var sum = 0
                for dy in -1...1 {
                    for dx in -1...1 { sum += Int(luma.at(px + CGFloat(dx) * step, py + CGFloat(dy) * step)) }
                }
                values[y * width + x] = UInt8(sum / 9)
            }
        }
        let sorted = values.sorted()
        // Fine background guilloches must not join the face to the entire card.
        let threshold = max(100, min(ceiling, Int(sorted[sorted.count * 9 / 10]) - 35))
        let monochrome = monochromeFace.map {
            monochromePixels(face: $0, bounds: bounds, width: width, height: height)
        } ?? []
        var seedBottom = seed.maxY
        var portraitBottom: CGFloat?
        if let face = monochromeFace, !monochrome.isEmpty,
           let anchor = darkBounds(seed: face, within: bounds, excluding: text, margin: 0) {
            seedBottom = min(seedBottom, anchor.maxY + face.height * 0.06)
            portraitBottom = anchor.maxY + face.height * 0.02 + margin / CGFloat(luma.height)
        }
        let barriers = monochromeFace.map { face in
            text.filter { $0.intersectionArea(face) < face.area * 0.2 }
        } ?? []
        var blocked = [Bool](repeating: false, count: values.count)
        for y in 0..<height { for x in 0..<width {
            let point = CGPoint(x: bounds.minX + CGFloat(x) * step / CGFloat(luma.width),
                                y: bounds.minY + CGFloat(y) * step / CGFloat(luma.height))
            blocked[y * width + x] = barriers.contains { $0.contains(point) }
        } }
        func foreground(_ index: Int) -> Bool {
            !blocked[index] && (values[index] < threshold || (!monochrome.isEmpty && monochrome[index]))
        }
        var visited = [Bool](repeating: false, count: values.count)
        var pending: [Int] = []
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: bounds.minX + CGFloat(x) * step / CGFloat(luma.width),
                                    y: bounds.minY + CGFloat(y) * step / CGFloat(luma.height))
                if seed.contains(point), point.y <= seedBottom,
                   !text.contains(where: { $0.contains(point) }), foreground(y * width + x) {
                    visited[y * width + x] = true
                    pending.append(y * width + x)
                }
            }
        }
        var head = 0, left = width, right = -1, top = height, bottom = -1
        while head < pending.count {
            let index = pending[head]
            head += 1
            let x = index % width, y = index / width
            left = min(left, x)
            right = max(right, x)
            top = min(top, y)
            bottom = max(bottom, y)
            for ny in max(0, y - 1)...min(height - 1, y + 1) {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    let next = ny * width + nx
                    if !visited[next], foreground(next) {
                        visited[next] = true
                        pending.append(next)
                    }
                }
            }
        }
        guard right > left, bottom > top else { return nil }
        let region = CGRect(x: bounds.minX + (CGFloat(left) * step - margin) / CGFloat(luma.width),
                            y: bounds.minY + (CGFloat(top) * step - margin) / CGFloat(luma.height),
                            width: (CGFloat(right - left + 1) * step + 2 * margin) / CGFloat(luma.width),
                            height: (CGFloat(bottom - top + 1) * step + 2 * margin) / CGFloat(luma.height))
        var result = region.intersection(bounds)
        if let portraitBottom, result.maxY > portraitBottom {
            result.size.height = max(0, portraitBottom - result.minY)
        }
        return result
    }

    /// Pale clothing on a monochrome printed portrait can be as light as the card.
    /// Use its colour separation from the surrounding security print only when that
    /// separation is measurable; a coloured portrait keeps the luminance fallback.
    private func monochromePixels(face: CGRect, bounds: CGRect, width: Int, height: Int) -> [Bool] {
        let pixels = CGRect(x: bounds.minX * CGFloat(image.width), y: bounds.minY * CGFloat(image.height),
                            width: bounds.width * CGFloat(image.width), height: bounds.height * CGFloat(image.height)).integral
        guard let crop = image.cropping(to: pixels) else { return [] }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }
        var colours = [CGPoint](repeating: .zero, count: width * height)
        var fg: [CGPoint] = [], bg: [CGPoint] = []
        let core = face.insetBy(dx: face.width * 0.2, dy: face.height * 0.2)
        for y in 0..<height { for x in 0..<width {
            var red = 0, green = 0, blue = 0, samples = 0
            for yy in max(0, y - 1)...min(height - 1, y + 1) {
                for xx in max(0, x - 1)...min(width - 1, x + 1) {
                    let i = (yy * width + xx) * 4
                    red += Int(rgba[i]); green += Int(rgba[i + 1]); blue += Int(rgba[i + 2]); samples += 1
                }
            }
            let colour = CGPoint(x: CGFloat(red - green) / CGFloat(samples), y: CGFloat(blue - green) / CGFloat(samples))
            colours[y * width + x] = colour
            let point = CGPoint(x: bounds.minX + CGFloat(x) / CGFloat(width) * bounds.width,
                                y: bounds.minY + CGFloat(y) / CGFloat(height) * bounds.height)
            if core.contains(point) { fg.append(colour) }
            else if y < height / 12 || x < width / 20 || x >= width * 19 / 20 { bg.append(colour) }
        } }
        guard fg.count > 8, bg.count > 8 else { return [] }
        func median(_ samples: [CGPoint]) -> CGPoint {
            CGPoint(x: samples.map(\.x).sorted()[samples.count / 2], y: samples.map(\.y).sorted()[samples.count / 2])
        }
        let portrait = median(fg), background = median(bg)
        guard dist(portrait, .zero) < 25, dist(portrait, background) > 15 else { return [] }
        return colours.enumerated().map { i, colour in
            rgba[i * 4] < 240 && dist(colour, portrait) + 4 < dist(colour, background)
        }
    }

    /// These security features can contain a photographic silhouette that face detection misses.
    /// The document family limits the search, while actual detected edges determine the mask.
    func windows(country: String?, kind: DocumentKind, existing: [Finding]) -> [Quad] {
        let candidates = frames.filter { quad in
            let box = quad.boundingRect
            guard !existing.contains(where: { $0.kind == .photo && $0.rect.intersectionArea(box) > box.area * 0.5 }) else { return false }
            let ratio = box.width * aspect / box.height
            if country == "NO", kind == .idCard {
                return (0.55...0.95).contains(ratio) && (0.015...0.06).contains(box.area)
                    && box.minY > 0.17 && box.maxY < 0.67
                    && box.minX > 0.13 && box.maxX < 0.9
            }
            if country == "NL", kind == .idCard {
                return (0.55...1.1).contains(ratio) && (0.02...0.07).contains(box.area)
                    && box.minX > 0.65 && box.maxX < 0.92 && box.minY > 0.35 && box.maxY < 0.85
            }
            if country == "NO", kind == .drivingLicence {
                return (0.65...1.1).contains(ratio) && (0.03...0.09).contains(box.area)
                    && box.minX > 0.7 && box.maxX < 0.98 && box.minY > 0.35 && box.maxY < 0.85
            }
            if country == "NL", kind == .drivingLicence {
                return (0.55...1.4).contains(ratio) && (0.006...0.03).contains(box.area)
                    && box.minX > 0.6 && box.maxX < 0.96
                    && box.minY > 0.4 && box.maxY < 0.85
            }
            return false
        }
        var windows = candidates.filter { outer in
            !candidates.contains { inner in
                inner.area() < outer.area() * 0.7 && inner.area() > outer.area() * 0.4
                    && inner.points.allSatisfy { outer.contains($0) }
            }
        }
        if country == "NL", kind == .drivingLicence {
            // Dutch licences have a neighbouring transparent window and small printed portrait.
            windows = candidates.filter { candidate in
                candidates.contains {
                    let a = candidate.boundingRect, b = $0.boundingRect
                    return abs(a.midY - b.midY) < max(a.height, b.height) * 0.4
                        && (b.minX - a.maxX > 0 && b.minX - a.maxX < 0.06
                            || a.minX - b.maxX > 0 && a.minX - b.maxX < 0.06)
                }
            }
        }
        var measured = windows.map { window -> Quad in
            let box = window.boundingRect
            let search = box.insetBy(dx: -box.width * 0.15, dy: -box.height * 0.15).clampedToUnit()
            // Some transparent windows are not rectangular. Cover their rectangular extent,
            // including the edge a rectangle detector can cut across.
            if let extent = darkBounds(seed: box, within: search), extent.area > box.area * 0.6 {
                return Quad(box.union(extent).clampedToUnit())
            }
            return Quad(box)
        }
        if country == "NO", kind == .idCard, !windows.isEmpty {
            // The Norwegian ID back has a wide security patch beside the cutout. Its right
            // half contains another portrait, too small for a dependable whole-page face read.
            for frame in frames {
                let box = frame.boundingRect
                let ratio = box.width * aspect / box.height
                guard (1.2...1.6).contains(ratio), (0.03...0.07).contains(box.area),
                      box.minX > 0.42, box.maxX < 0.8, box.minY > 0.18, box.maxY < 0.55 else { continue }
                let right = CGRect(x: box.minX + box.width * 0.43, y: box.minY,
                                   width: box.width * 0.57, height: box.height)
                if let extent = darkBounds(seed: right.insetBy(dx: right.width * 0.2, dy: right.height * 0.2), within: right),
                   extent.height > box.height * 0.4, extent.width > box.width * 0.2 {
                    measured.append(Quad(extent))
                }
            }
        }
        return measured
    }
}
