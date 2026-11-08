import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import os

public struct Watermark: Sendable {
    public var recipient: String
    public var purpose: String
    public var date: Date

    public init(recipient: String, purpose: String = "", date: Date = Date()) {
        self.recipient = recipient
        self.purpose = purpose
        self.date = date
    }

    public var lines: [String] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM yyyy"
        return ["COPY · " + f.string(from: date).uppercased(),
                recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                purpose.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
    }

    public var text: String { lines.joined(separator: " · ") }
}

/// Flattened, opaque redactions and an in-document watermark. No recoverable layers or metadata.
public enum Renderer {
    public static let maskColor = CGColor(srgbRed: 0.19, green: 0.21, blue: 0.23, alpha: 1)
    private static let signposter = OSSignposter(subsystem: "com.feiyangtang.Maske", category: "PointsOfInterest")

    public static func render(pages: [(CGImage, [Finding])], watermark: Watermark?, maxWidth: Int = 1600) -> CGImage? {
        let interval = signposter.beginInterval("RenderCopy")
        defer { signposter.endInterval("RenderCopy", interval) }
        guard !pages.isEmpty, maxWidth > 0, !Task.isCancelled else { return nil }
        let width = min(maxWidth, pages.map(\.0.width).max() ?? maxWidth)
        let gap = pages.count > 1 ? width / 24 : 0
        let heights = pages.map { Int((CGFloat($0.0.height) * CGFloat(width) / CGFloat($0.0.width)).rounded()) }
        let height = heights.reduce(0, +) + gap * (pages.count - 1)
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .high
        var top = 0
        for (i, (image, findings)) in pages.enumerated() {
            guard !Task.isCancelled else { return nil }
            let frame = CGRect(x: 0, y: height - top - heights[i], width: width, height: heights[i])
            ctx.saveGState()
            ctx.clip(to: frame)
            ctx.draw(image, in: frame)
            ctx.setFillColor(maskColor)
            let redactions = CGMutablePath()
            for f in findings where f.isOn {
                let pts = f.shape.points.map { CGPoint(x: frame.minX + $0.x * frame.width, y: frame.maxY - $0.y * frame.height) }
                let path = CGMutablePath()
                path.addLines(between: pts)
                path.closeSubpath()
                redactions.addPath(path)
                ctx.addPath(path)
                ctx.fillPath()
            }
            if let watermark {
                ctx.saveGState()
                ctx.clip(to: frame)
                ctx.translateBy(x: frame.midX, y: frame.midY)
                ctx.rotate(by: .pi / 7.5)
                draw(watermark, in: ctx, size: frame.size)
                ctx.restoreGState()
                if !redactions.isEmpty {
                    ctx.saveGState()
                    ctx.addPath(redactions)
                    ctx.clip()
                    ctx.translateBy(x: frame.midX, y: frame.midY)
                    ctx.rotate(by: .pi / 7.5)
                    draw(watermark, in: ctx, size: frame.size, light: true)
                    ctx.restoreGState()
                }
            }
            ctx.restoreGState()
            top += heights[i] + gap
        }
        return Task.isCancelled ? nil : ctx.makeImage()
    }

    /// Fit every character into a central block; the date and purpose stay on each page.
    static func draw(_ watermark: Watermark, in ctx: CGContext, size: CGSize, light: Bool = false) {
        let width = min(size.width * 0.77, size.height * 1.35)
        let maxHeight = min(size.height * 0.42, size.width * 0.45)
        let text = watermark.lines.joined(separator: "\n")
        var fontSize = min(size.width / 20, size.height / 8)
        var alignment = CTTextAlignment.center
        let paragraph = withUnsafePointer(to: &alignment) { pointer in
            var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: pointer)
            return CTParagraphStyleCreate(&setting, 1)
        }
        func framesetter(_ points: CGFloat) -> CTFramesetter {
            let attributes: [NSAttributedString.Key: Any] = [
                .init(kCTFontAttributeName as String): CTFontCreateWithName("HelveticaNeue-Medium" as CFString, points, nil),
                .init(kCTForegroundColorAttributeName as String): light
                    ? CGColor(gray: 1, alpha: 0.65)
                    : CGColor(srgbRed: 0.12, green: 0.22, blue: 0.27, alpha: 0.30),
                .init(kCTParagraphStyleAttributeName as String): paragraph,
            ]
            return CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        }
        var setter = framesetter(fontSize)
        var fitted = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        while fitted.height > maxHeight && fontSize > 2 {
            fontSize *= 0.9
            setter = framesetter(fontSize)
            fitted = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
                CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        }
        let height = ceil(fitted.height) + 2
        let path = CGPath(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), transform: nil)
        ctx.textMatrix = .identity
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(), path, nil), ctx)
    }

    public static func jpegData(_ image: CGImage, quality: CGFloat = 0.85) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
