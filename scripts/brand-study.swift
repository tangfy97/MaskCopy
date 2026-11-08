#!/usr/bin/env swift
// Reversible logo studies; never overwrites the installed AppIcon.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Design/Studies/2026-11-08")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ value: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: 1)
}
let paper = color(0xF4F3EF), ink = color(0x1A1A1A)
func rounded(_ c: CGContext, _ rect: CGRect, _ radius: CGFloat, fill: CGColor? = nil, stroke: CGColor? = nil, width: CGFloat = 32) {
    let p = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    if let fill { c.setFillColor(fill); c.addPath(p); c.fillPath() }
    if let stroke { c.setStrokeColor(stroke); c.setLineWidth(width); c.addPath(p); c.strokePath() }
}
func shackle(_ c: CGContext, x: CGFloat, top: CGFloat, width: CGFloat, bottom: CGFloat, ink: CGColor, line: CGFloat) {
    c.setStrokeColor(ink); c.setLineWidth(line); c.setLineCap(.round)
    c.move(to: CGPoint(x: x, y: bottom))
    c.addLine(to: CGPoint(x: x, y: top + width / 2))
    c.addCurve(to: CGPoint(x: x + width, y: top + width / 2),
               control1: CGPoint(x: x, y: top - width / 6),
               control2: CGPoint(x: x + width, y: top - width / 6))
    c.addLine(to: CGPoint(x: x + width, y: bottom)); c.strokePath()
}
func mark(_ c: CGContext, variant: Int, in rect: CGRect, dark: Bool = false) {
    c.saveGState(); defer { c.restoreGState() }
    c.translateBy(x: rect.minX, y: rect.minY); c.scaleBy(x: rect.width / 1000, y: rect.height / 1000)
    let foreground = dark ? paper : ink, background = dark ? ink : paper
    let muted = foreground.copy(alpha: 0.35)!
    let card = variant == 2 ? CGRect(x: 160, y: 280, width: 660, height: 420) : CGRect(x: 170, y: 290, width: 660, height: 420)
    rounded(c, card, 60, stroke: foreground)
    if variant == 0 {
        // The portrait becomes a lock, retaining the card's existing visual balance.
        shackle(c, x: 280, top: 367, width: 100, bottom: 455, ink: foreground, line: 27)
        rounded(c, CGRect(x: 257, y: 441, width: 146, height: 116), 20, fill: foreground)
        c.setFillColor(background); c.fillEllipse(in: CGRect(x: 318, y: 477, width: 24, height: 24))
        rounded(c, CGRect(x: 324, y: 491, width: 12, height: 28), 5, fill: background)
    } else {
        c.setStrokeColor(foreground); c.setLineWidth(27)
        c.strokeEllipse(in: CGRect(x: 259, y: 364, width: 130, height: 130))
    }
    rounded(c, CGRect(x: 464, y: 370, width: 278, height: 76), 12, fill: foreground)
    rounded(c, CGRect(x: 464, y: 518, width: 210, height: 32), 10, fill: muted)
    rounded(c, CGRect(x: 259, y: 599, width: 483, height: 32), 10, fill: muted)
    if variant == 1 {
        // Negative-space lock lives inside the redaction, without an extra badge.
        shackle(c, x: 672, top: 382, width: 28, bottom: 409, ink: background, line: 8)
        rounded(c, CGRect(x: 662, y: 401, width: 48, height: 32), 6, fill: background)
    } else if variant == 2 {
        // A larger corner lock remains legible at app-icon size.
        rounded(c, CGRect(x: 619, y: 542, width: 242, height: 224), 40, fill: background)
        shackle(c, x: 674, top: 534, width: 106, bottom: 634, ink: foreground, line: 29)
        rounded(c, CGRect(x: 641, y: 615, width: 172, height: 133), 24, fill: foreground)
        c.setFillColor(background); c.fillEllipse(in: CGRect(x: 714, y: 651, width: 27, height: 27))
        rounded(c, CGRect(x: 721, y: 669, width: 13, height: 28), 5, fill: background)
    }
}
func context(_ width: Int, _ height: Int, fill: CGColor) -> CGContext {
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setFillColor(fill); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
    c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 1, y: -1)
    return c
}
func save(_ c: CGContext, _ filename: String) {
    let d = CGImageDestinationCreateWithURL(output.appendingPathComponent(filename) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, c.makeImage()!, nil); CGImageDestinationFinalize(d)
}
func text(_ c: CGContext, _ value: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, tint: CGColor = ink) {
    c.saveGState(); defer { c.restoreGState() }
    c.translateBy(x: x, y: y + size); c.scaleBy(x: 1, y: -1)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName((bold ? "HelveticaNeue-Medium" : "HelveticaNeue") as CFString, size, nil),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): tint
    ]))
    c.textPosition = .zero; CTLineDraw(line, c)
}
let names = ["A — Privacy card", "B — Locked mask", "C — Protected copy"]
for v in 0..<3 {
    for dark in [false, true] {
        let c = context(1024, 1024, fill: dark ? ink : paper)
        mark(c, variant: v, in: CGRect(x: 0, y: 0, width: 1024, height: 1024), dark: dark)
        save(c, "\(["A","B","C"][v])-\(dark ? "dark" : "light").png")
    }
}
let board = context(1536, 1040, fill: color(0xFFFFFF))
text(board, "MaskCopy", x: 64, y: 40, size: 32, bold: true)
text(board, "Privacy mark studies", x: 64, y: 86, size: 20, tint: color(0x586A70))
for v in 0..<3 {
    let x = CGFloat(v) * 488 + 48
    text(board, names[v], x: x + 16, y: 144, size: 24, bold: true)
    let r = CGRect(x: x + 48, y: 208, width: 336, height: 336)
    rounded(board, r, 76, fill: paper)
    mark(board, variant: v, in: r)
    for (index, size) in [CGFloat(64), CGFloat(40), CGFloat(24)].enumerated() {
        let small = CGRect(x: x + 80 + CGFloat(index) * 104, y: 592 + (64 - size) / 2, width: size, height: size)
        rounded(board, small, size * 0.23, fill: paper)
        mark(board, variant: v, in: small)
    }
    let dark = CGRect(x: x + 128, y: 724, width: 176, height: 176)
    rounded(board, dark, 40, fill: ink); mark(board, variant: v, in: dark, dark: true)
    mark(board, variant: v, in: CGRect(x: x + 168, y: 932, width: 96, height: 96))
}
save(board, "comparison.png")
print("Logo studies: \(output.path)")
