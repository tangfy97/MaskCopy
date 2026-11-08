#!/usr/bin/env swift
// Renders the app icon: a redacted card with a prominent corner lock (owner-selected C).
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

// Normalized top-left artwork matches the selected C study.
ctx.translateBy(x: 0, y: 1024)
ctx.scaleBy(x: 1.024, y: -1.024)
func rounded(_ rect: CGRect, _ radius: CGFloat, fill: CGColor? = nil, stroke: CGColor? = nil) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    if let fill { ctx.setFillColor(fill); ctx.addPath(path); ctx.fillPath() }
    if let stroke { ctx.setStrokeColor(stroke); ctx.setLineWidth(32); ctx.addPath(path); ctx.strokePath() }
}
rounded(CGRect(x: 160, y: 280, width: 660, height: 420), 60, stroke: ink)
ctx.setStrokeColor(ink); ctx.setLineWidth(27)
ctx.strokeEllipse(in: CGRect(x: 259, y: 364, width: 130, height: 130))
rounded(CGRect(x: 464, y: 370, width: 278, height: 76), 12, fill: ink)
rounded(CGRect(x: 464, y: 518, width: 210, height: 32), 10, fill: rgb(0x1A1A1A, 0.35))
rounded(CGRect(x: 259, y: 599, width: 483, height: 32), 10, fill: rgb(0x1A1A1A, 0.35))
rounded(CGRect(x: 570, y: 482, width: 286, height: 314), 40, fill: paper)
ctx.setStrokeColor(ink); ctx.setLineWidth(34); ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 645, y: 626)); ctx.addLine(to: CGPoint(x: 645, y: 570))
ctx.addCurve(to: CGPoint(x: 771, y: 570), control1: CGPoint(x: 645, y: 486), control2: CGPoint(x: 771, y: 486))
ctx.addLine(to: CGPoint(x: 771, y: 626)); ctx.strokePath()
rounded(CGRect(x: 596, y: 604, width: 224, height: 166), 28, fill: ink)
ctx.setFillColor(paper); ctx.fillEllipse(in: CGRect(x: 692, y: 649, width: 32, height: 32))
rounded(CGRect(x: 700, y: 671, width: 16, height: 34), 6, fill: paper)

let image = ctx.makeImage()!
for path in ["Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "Design/AppIcon-1024.png"] {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}
print("Wrote the app icon")
