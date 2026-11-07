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
        var parts = ["COPY FOR \(recipient.trimmingCharacters(in: .whitespaces).uppercased())"]
        let p = purpose.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { parts.append(p.uppercased()) }
        parts.append(f.string(from: date).uppercased())
        return parts.joined(separator: "  ·  ")
    }
}

/// Makes the copy that is shared: masks painted into the pixels (never blurred, which can be
/// undone), a watermark across the whole document, a smaller size, and no metadata.
public enum Renderer {
    public static let maskColor = CGColor(srgbRed: 0.09, green: 0.09, blue: 0.09, alpha: 1)

    public static func render(pages: [(CGImage, [Finding])], watermark: Watermark?, maxWidth: Int = 1600) -> CGImage? {
        guard !pages.isEmpty else { return nil }
        let width = min(maxWidth, pages.map(\.0.width).max() ?? maxWidth)
        let gap = pages.count > 1 ? width / 24 : 0
        let heights = pages.map { Int((CGFloat($0.0.height) * CGFloat(width) / CGFloat($0.0.width)).rounded()) }
        let height = heights.reduce(0, +) + gap * (pages.count - 1)

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
                let r = CGRect(x: frame.minX + f.rect.minX * frame.width,
                               y: frame.maxY - f.rect.maxY * frame.height,
                               width: f.rect.width * frame.width, height: f.rect.height * frame.height)
                let radius = min(r.width, r.height) * 0.12
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
                ctx.fillPath()
            }
            top += h + gap
        }

        if let watermark { draw(watermark.text, in: ctx, size: CGSize(width: width, height: height)) }
        return ctx.makeImage()
    }

    static func draw(_ text: String, in ctx: CGContext, size: CGSize) {
        let fontSize = max(14, size.width / 30)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        func line(_ color: CGColor) -> CTLine {
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
                NSAttributedString.Key(kCTKernAttributeName as String): fontSize * 0.08,
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: text + "      ", attributes: attrs))
        }
        let dark = line(CGColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 0.32))
        let light = line(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.38))
        let lineWidth = CTLineGetTypographicBounds(dark, nil, nil, nil)
        guard lineWidth > 0 else { return }

        ctx.saveGState()
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: .pi / 7)
        let diagonal = hypot(size.width, size.height)
        let step = fontSize * 3.4
        var y = -diagonal / 2
        var row = 0
        while y < diagonal / 2 {
            var x = -diagonal / 2 - CGFloat(row % 2) * lineWidth / 2
            while x < diagonal / 2 {
                ctx.textPosition = CGPoint(x: x + 1.5, y: y - 1.5)
                CTLineDraw(light, ctx)
                ctx.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(dark, ctx)
                x += lineWidth
            }
            y += step
            row += 1
        }
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
