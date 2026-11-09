import AppKit

// Composes an App Store screenshot: a headline and a subline on the app's paper colour, above a
// Simulator capture with rounded corners and a soft shadow. Default 1206×2622, the size App Store
// Connect requires for "iPhone with Dynamic Island (medium display)" (6.1"/6.3"); it is scaled
// down for smaller iPhones.
//
//   swift scripts/storeshot.swift <capture.png> <out.png> <headline> <subline> [width height]
//
// Captures come from `xcrun simctl io <device> screenshot` on an iPhone 18 Pro Max Simulator with
// the status bar overridden to 9:41, using synthetic documents only (see docs/APP_STORE.md).
let args = CommandLine.arguments
guard args.count == 5 || args.count == 7, let capture = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    print("usage: storeshot.swift <capture.png> <out.png> <headline> <subline> [width height]")
    exit(2)
}
let out = URL(fileURLWithPath: args[2])
let headline = args[3], subline = args[4]

let W: CGFloat = args.count == 7 ? CGFloat(Double(args[5])!) : 1206
let H: CGFloat = args.count == 7 ? CGFloat(Double(args[6])!) : 2622
// Layout was designed at 1320 px wide; everything scales with the width.
let k = W / 1320
// App Store screenshots must not have an alpha channel: draw into an opaque sRGB context.
let cg = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

func rgb(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
// Theme.swift: paper 0xF5F5F1 (a shade darker here so the white screen stands out), ink 0x1C2B30, fjord 0x234E61.
rgb(0xE9EAE4).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

let centred = NSMutableParagraphStyle()
centred.alignment = .center
centred.lineSpacing = 4 * k
let head = NSAttributedString(string: headline, attributes: [
    .font: NSFont.systemFont(ofSize: 92 * k, weight: .bold),
    .foregroundColor: rgb(0x1C2B30),
    .paragraphStyle: centred,
    .kern: -1.2 * k,
])
let sub = NSAttributedString(string: subline, attributes: [
    .font: NSFont.systemFont(ofSize: 50 * k, weight: .regular),
    .foregroundColor: rgb(0x234E61),
    .paragraphStyle: centred,
])
let textWidth = W - 160 * k
let headRect = head.boundingRect(with: NSSize(width: textWidth, height: 400), options: [.usesLineFragmentOrigin])
let subRect = sub.boundingRect(with: NSSize(width: textWidth, height: 300), options: [.usesLineFragmentOrigin])
let top: CGFloat = 170 * k
head.draw(with: NSRect(x: 80 * k, y: H - top - headRect.height, width: textWidth, height: headRect.height), options: [.usesLineFragmentOrigin])
sub.draw(with: NSRect(x: 80 * k, y: H - top - headRect.height - 28 * k - subRect.height, width: textWidth, height: subRect.height), options: [.usesLineFragmentOrigin])

// The capture, scaled to fit under the text, with the corner radius of the device's screen.
let textBottom = top + headRect.height + 28 * k + subRect.height + 90 * k
let available = H - textBottom - 110 * k
let scale = min((W - 220 * k) / capture.size.width, available / capture.size.height)
let size = NSSize(width: capture.size.width * scale, height: capture.size.height * scale)
let frame = NSRect(x: (W - size.width) / 2, y: H - textBottom - size.height, width: size.width, height: size.height)
let radius = 62 * scale * (capture.size.width / 440)
let shape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
shadow.shadowBlurRadius = 60 * k
shadow.shadowOffset = NSSize(width: 0, height: -24 * k)
shadow.set()
NSColor.white.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
shape.addClip()
capture.draw(in: frame)
NSGraphicsContext.restoreGraphicsState()
rgb(0x1C2B30).withAlphaComponent(0.12).setStroke()
shape.lineWidth = 2 * k
shape.stroke()

NSGraphicsContext.restoreGraphicsState()
let image = cg.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(out.path)")
