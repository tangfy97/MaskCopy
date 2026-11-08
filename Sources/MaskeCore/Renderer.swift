import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct Watermark: Sendable {
    public var recipient: String
    public var purpose: String
    public var date: Date

    public init(recipient: String, purpose: String = "", date: Date = Date()) {
        self.recipient = recipient
        self.purpose = purpose
        self.date = date
    }

    public var text: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM yyyy"
        var parts = ["COPY FOR \(recipient.trimmingCharacters(in: .whitespacesAndNewlines))"]
        let p = purpose.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { parts.append(p) }
        parts.append(f.string(from: date).uppercased())
        return parts.joined(separator: "  ·  ")
    }
}

/// Makes the copy that is shared: masks painted into the pixels (never blurred, which can be
/// undone), a watermark across the whole document, a smaller size, and no metadata.
public enum Renderer {
    public static let maskColor = CGColor(srgbRed: 0.76, green: 0.80, blue: 0.82, alpha: 1)

    public static func render(pages: [(CGImage, [Finding])], watermark: Watermark?, maxWidth: Int = 1600) -> CGImage? {
        guard !pages.isEmpty else { return nil }
        let width = min(maxWidth, pages.map(\.0.width).max() ?? maxWidth)
        let gap = pages.count > 1 ? width / 24 : 0
        let heights = pages.map { Int((CGFloat($0.0.height) * CGFloat(width) / CGFloat($0.0.width)).rounded()) }
        let padding = max(16, CGFloat(width) * 0.025)
        let footer = watermark.map { watermark -> CTFramesetter in
            let font = CTFontCreateWithName("Helvetica" as CFString, max(14, CGFloat(width) / 48), nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0.21, green: 0.29, blue: 0.32, alpha: 1),
            ]
            return CTFramesetterCreateWithAttributedString(NSAttributedString(string: watermark.text, attributes: attributes))
        }
        let footerHeight = footer.map {
            Int(ceil(CTFramesetterSuggestFrameSizeWithConstraints($0, CFRange(), nil,
                CGSize(width: CGFloat(width) - padding * 2, height: .greatestFiniteMagnitude), nil).height + padding * 2))
        } ?? 0
        let height = heights.reduce(0, +) + gap * (pages.count - 1) + footerHeight

        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .high

        var top = 0
        for (i, (image, findings)) in pages.enumerated() {
            let h = heights[i]
            // CoreGraphics draws from the bottom left.
            let frame = CGRect(x: 0, y: height - top - h, width: width, height: h)
            ctx.draw(image, in: frame)
            ctx.setFillColor(maskColor)
            for f in findings where f.isOn {
                // Paint exactly the reviewed shape. Ink fitting already supplies its safety margin.
                let pts = f.shape.points.map { CGPoint(x: frame.minX + $0.x * frame.width, y: frame.maxY - $0.y * frame.height) }
                let path = CGMutablePath()
                path.addLines(between: pts)
                path.closeSubpath()
                ctx.addPath(path)
                ctx.fillPath()
            }
            if let watermark {
                ctx.saveGState()
                ctx.clip(to: frame)
                ctx.translateBy(x: frame.minX, y: frame.minY)
                draw("COPY FOR " + watermark.recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                     in: ctx, size: frame.size)
                ctx.restoreGState()
            }
            top += h + gap
        }

        if let footer {
            ctx.setStrokeColor(CGColor(srgbRed: 0.83, green: 0.86, blue: 0.87, alpha: 1))
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: padding, y: CGFloat(footerHeight)))
            ctx.addLine(to: CGPoint(x: CGFloat(width) - padding, y: CGFloat(footerHeight)))
            ctx.strokePath()
            let frame = CGPath(rect: CGRect(x: padding, y: padding, width: CGFloat(width) - padding * 2,
                                            height: CGFloat(footerHeight) - padding * 2), transform: nil)
            ctx.textMatrix = .identity
            CTFrameDraw(CTFramesetterCreateFrame(footer, CFRange(), frame, nil), ctx)
        }
        return ctx.makeImage()
    }

    static func draw(_ text: String, in ctx: CGContext, size: CGSize) {
        func line(_ fontSize: CGFloat, text: String = text) -> CTLine {
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0.12, green: 0.23, blue: 0.28, alpha: 0.10),
                NSAttributedString.Key(kCTKernAttributeName as String): fontSize * 0.03,
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        }
        let fontSize = max(14, size.width / 25)
        let draft = line(fontSize)
        let lineWidth = CTLineGetTypographicBounds(draft, nil, nil, nil)
        guard lineWidth > 0, size.width > 0 else { return }
        let fitted = line(max(10, fontSize * min(1, size.width * 0.8 / lineWidth)))
        let mark = CTLineCreateTruncatedLine(fitted, Double(size.width * 0.8), .end, line(10, text: "…")) ?? fitted

        ctx.saveGState()
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: .pi / 12)
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: -CTLineGetTypographicBounds(mark, nil, nil, nil) / 2, y: 0)
        CTLineDraw(mark, ctx)
        ctx.restoreGState()
    }

    /// JPEG with no metadata: no EXIF, no location, no camera details.
    public static func jpegData(_ image: CGImage, quality: CGFloat = 0.85) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
