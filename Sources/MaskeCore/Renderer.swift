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
        let context = [purpose.trimmingCharacters(in: .whitespacesAndNewlines), f.string(from: date)]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        return ["Copy for " + recipient.trimmingCharacters(in: .whitespacesAndNewlines), context]
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
                ctx.rotate(by: .pi / 6)
                draw(watermark, in: ctx, size: frame.size)
                ctx.restoreGState()
                if !redactions.isEmpty {
                    ctx.saveGState()
                    ctx.addPath(redactions)
                    ctx.clip()
                    ctx.translateBy(x: frame.midX, y: frame.midY)
                    ctx.rotate(by: .pi / 6)
                    draw(watermark, in: ctx, size: frame.size, light: true)
                    ctx.restoreGState()
                }
            }
            ctx.restoreGState()
            top += heights[i] + gap
        }
        return Task.isCancelled ? nil : ctx.makeImage()
    }

    /// Uniform translucent lettering; multiply preserves dark document printing.
    static func draw(_ watermark: Watermark, in ctx: CGContext, size: CGSize, light: Bool = false) {
        let width = min(size.width * 0.82, size.height * 1.55)
        let maxHeight = min(size.height * 0.20, size.width * 0.18)
        var fontSize = min(size.width / 28, size.height / 12)
        let color = light ? CGColor(gray: 1, alpha: 0.66)
            : CGColor(srgbRed: 0.74, green: 0.12, blue: 0.18, alpha: 0.38)
        ctx.setBlendMode(light ? .normal : .multiply)
        var alignment = CTTextAlignment.center
        let paragraph = withUnsafePointer(to: &alignment) { pointer in
            var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: pointer)
            return CTParagraphStyleCreate(&setting, 1)
        }
        func framesetter(_ points: CGFloat) -> CTFramesetter {
            let attributes: [NSAttributedString.Key: Any] = [
                .init(kCTFontAttributeName as String): CTFontCreateWithName("HelveticaNeue-Medium" as CFString, points, nil),
                .init(kCTForegroundColorAttributeName as String): color,
                .init(kCTParagraphStyleAttributeName as String): paragraph,
            ]
            return CTFramesetterCreateWithAttributedString(NSAttributedString(string: watermark.lines.joined(separator: "\n"), attributes: attributes))
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

    /// A single-page PDF containing only the same flattened JPEG pixels as image export.
    /// No text objects, annotations, source image, metadata dictionary or recoverable mask layer.
    public static func pdfData(_ image: CGImage) -> Data? {
        guard !Task.isCancelled, let jpeg = jpegData(image) else { return nil }
        let width = 612
        let height = max(1, Int((Double(image.height) / Double(image.width) * Double(width)).rounded()))
        let commands = Data("q\n\(width) 0 0 \(height) 0 0 cm\n/Copy Do\nQ\n".utf8)
        var data = Data("%PDF-1.4\n".utf8)
        data.append(contentsOf: [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A])
        var offsets = [0]
        func object(_ body: Data) {
            offsets.append(data.count)
            data.append(Data("\(offsets.count - 1) 0 obj\n".utf8))
            data.append(body)
            data.append(Data("\nendobj\n".utf8))
        }
        object(Data("<< /Type /Catalog /Pages 2 0 R >>".utf8))
        object(Data("<< /Type /Pages /Kids [3 0 R] /Count 1 >>".utf8))
        object(Data("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(width) \(height)] /Resources << /XObject << /Copy 4 0 R >> >> /Contents 5 0 R >>".utf8))
        var pixels = Data("<< /Type /XObject /Subtype /Image /Width \(image.width) /Height \(image.height) /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length \(jpeg.count) >>\nstream\n".utf8)
        pixels.append(jpeg)
        pixels.append(Data("\nendstream".utf8))
        object(pixels)
        var content = Data("<< /Length \(commands.count) >>\nstream\n".utf8)
        content.append(commands)
        content.append(Data("endstream".utf8))
        object(content)
        let xref = data.count
        data.append(Data("xref\n0 \(offsets.count)\n0000000000 65535 f \n".utf8))
        for offset in offsets.dropFirst() {
            data.append(Data(String(format: "%010d 00000 n \n", offset).utf8))
        }
        data.append(Data("trailer\n<< /Size \(offsets.count) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n".utf8))
        return Task.isCancelled ? nil : data
    }

    public static func jpegData(_ image: CGImage, quality: CGFloat = 0.85) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
