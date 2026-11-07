#!/usr/bin/env swift
// Renders the app icon: a card on paper with one line blacked out.
// Usage: scripts/icon.swift  (writes Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png and Design/AppIcon-1024.png)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let paper = rgb(0xF4F3EF), ink = rgb(0x1A1A1A)
ctx.setFillColor(paper)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Card (CoreGraphics' origin is bottom left).
let card = CGRect(x: 172, y: 302, width: 680, height: 430)
ctx.setStrokeColor(ink)
ctx.setLineWidth(34)
ctx.addPath(CGPath(roundedRect: card.insetBy(dx: 17, dy: 17), cornerWidth: 60, cornerHeight: 60, transform: nil))
ctx.strokePath()
// Portrait.
ctx.setLineWidth(28)
ctx.strokeEllipse(in: CGRect(x: 266, y: 518, width: 132, height: 132))
// The blacked-out line, and one left visible.
ctx.setFillColor(ink)
ctx.addPath(CGPath(roundedRect: CGRect(x: 470, y: 560, width: 290, height: 74), cornerWidth: 12, cornerHeight: 12, transform: nil))
ctx.fillPath()
ctx.setFillColor(rgb(0x1A1A1A, 0.35))
ctx.addPath(CGPath(roundedRect: CGRect(x: 470, y: 448, width: 220, height: 34), cornerWidth: 10, cornerHeight: 10, transform: nil))
ctx.fillPath()
ctx.addPath(CGPath(roundedRect: CGRect(x: 266, y: 400, width: 494, height: 34), cornerWidth: 10, cornerHeight: 10, transform: nil))
ctx.fillPath()

let image = ctx.makeImage()!
for path in ["Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "Design/AppIcon-1024.png"] {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}
print("Wrote the app icon")
