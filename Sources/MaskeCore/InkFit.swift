import CoreGraphics
import Foundation

/// The page in shades of grey, for looking at the actual pixels under a box.
struct Luma {
    let width: Int
    let height: Int
    let data: [UInt8]

    init?(_ image: CGImage) {
        let w = image.width, h = image.height
        var buffer = [UInt8](repeating: 0, count: w * h)
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        width = w
        height = h
        data = buffer
    }

    /// The grey level at a point in pixels (origin top left), nearest pixel, clamped to the page.
    @inline(__always) func at(_ x: CGFloat, _ y: CGFloat) -> UInt8 {
        let xi = min(max(Int(x), 0), width - 1), yi = min(max(Int(y), 0), height - 1)
        return data[yi * width + xi]
    }
}

/// Fits a box to the ink of the text inside it, so a mask covers exactly the characters:
/// all of them, including any that Vision's box cut through, and not the empty space around them.
enum InkFit {
    /// The ink of one line of text, measured in the line's own frame (u along the text, v across it, in pixels).
    struct Ink {
        let origin: CGPoint, ux: CGPoint, vy: CGPoint
        let w: CGFloat, h: CGFloat, step: CGFloat, u0: CGFloat, v0: CGFloat
        let colInk: [Int]
        let top: Int, bottom: Int, left: Int, right: Int
        let size: CGSize
        let bits: [Bool], cols: Int, rows: Int

        /// The ink rows over columns `l...r` only (taller characters elsewhere on the line don't count).
        func band(_ l: Int, _ r: Int) -> (Int, Int) {
            let rowInk = (0..<rows).map { row in (l...r).reduce(0) { $0 + (bits[row * cols + $1] ? 1 : 0) } }
            guard let seed = (top...bottom).max(by: { rowInk[$0] < rowInk[$1] }), rowInk[seed] > 0 else { return (top, bottom) }
            let gapMax = max(1, Int((0.14 * h / step).rounded()))
            var t = seed, b = seed, gap = 0, i = seed - 1
            while i >= top { if rowInk[i] > 0 { t = i; gap = 0 } else { gap += 1; if gap > gapMax { break } }; i -= 1 }
            gap = 0; i = seed + 1
            while i <= bottom { if rowInk[i] > 0 { b = i; gap = 0 } else { gap += 1; if gap > gapMax { break } }; i += 1 }
            return (t, b)
        }

        func u(_ c: Int) -> CGFloat { u0 + CGFloat(c) * step }
        func v(_ r: Int) -> CGFloat { v0 + CGFloat(r) * step }

        func column(at point: CGPoint) -> CGFloat {
            let delta = minus(CGPoint(x: point.x * size.width, y: point.y * size.height), origin)
            // The OCR frame can be skewed. Project along the frame's vertical axis.
            let along = (delta.x * vy.y - delta.y * vy.x) / (ux.x * vy.y - ux.y * vy.x)
            return (along - u0) / step
        }

        /// Ink columns grouped into runs separated by gaps of at least `gap` pixels.
        func runs(gap: CGFloat) -> [(Int, Int)] {
            let split = max(2, Int((gap / step).rounded()))
            var out: [(Int, Int)] = []
            var start = -1, last = -1
            for c in left...right where colInk[c] > 0 {
                if start < 0 { start = c } else if c - last > split { out.append((start, last)); start = c }
                last = c
            }
            if start >= 0 { out.append((start, last)) }
            return out
        }

        /// The box (in this frame, normalized to the page) around columns `l...r` and Vision's line height:
        /// used to measure a part of a line again, on its own.
        func region(_ l: Int, _ r: Int) -> Quad {
            let pad = 0.12 * h
            let le = u(l) - pad, ri = u(r + 1) + pad
            func at(_ uu: CGFloat, _ vv: CGFloat) -> CGPoint {
                let p = plus(plus(origin, scale(ux, uu)), scale(vy, vv))
                return CGPoint(x: p.x / size.width, y: p.y / size.height)
            }
            return Quad(tl: at(le, 0), tr: at(ri, 0), br: at(ri, h), bl: at(le, h))
        }

        /// The shape around columns `l...r` and the ink rows, grown by a thin margin, normalized to the page.
        func quad(_ l: Int, _ r: Int, margin: CGFloat) -> Quad {
            let (bt, bb) = (l == left && r == right) ? (top, bottom) : band(l, r)
            let t = v(bt), b = v(bb + 1), le = u(l), ri = u(r + 1)
            let m = max(3, margin * (b - t))
            func at(_ uu: CGFloat, _ vv: CGFloat) -> CGPoint {
                let p = plus(plus(origin, scale(ux, uu)), scale(vy, vv))
                return CGPoint(x: p.x / size.width, y: p.y / size.height)
            }
            return Quad(tl: at(le - m, t - m), tr: at(ri + m, t - m), br: at(ri + m, b + m), bl: at(le - m, b + m))
        }
    }

    /// Measures the ink of the text in `quad` (normalized to the page), or nil when the pixels don't show clear text.
    /// Vision's boxes can lean a few degrees off the text; the frame is turned to where the ink lies flattest.
    /// `extend` lets the fit run on past the box's ends into ink that continues (a character Vision's box cut);
    /// off when the ends are already known exactly.
    static func measure(_ quad: Quad, in luma: Luma, extend: Bool = true) -> Ink? {
        guard var ink = measureFrame(quad, in: luma, extend: extend) else { return nil }
        // Turn the frame to the text's angle, a few times until it lies flat.
        for _ in 0..<3 {
            guard let (level, turnedBy) = levelled(ink, in: luma, extend: extend) else { break }
            ink = level
            if abs(turnedBy) < 0.4 { break }
        }
        return ink
    }

    /// The same text measured in a frame turned to its angle, and by how much; nil if it already lies flat.
    static func levelled(_ base: Ink, in luma: Luma, extend: Bool) -> (Ink, CGFloat)? {
        let W = CGFloat(luma.width), H = CGFloat(luma.height)
        // The centre of the frame's box (u 0...w, v 0...h).
        let centre = plus(plus(base.origin, scale(base.ux, base.w / 2)), scale(base.vy, base.h / 2))
        func turned(_ degrees: CGFloat) -> Quad {
            let a = degrees * .pi / 180
            let ux = CGPoint(x: base.ux.x * cos(a) - base.ux.y * sin(a), y: base.ux.x * sin(a) + base.ux.y * cos(a))
            let vy = CGPoint(x: -ux.y, y: ux.x)
            let hw = scale(ux, base.w / 2), hh = scale(vy, base.h / 2)
            func n(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / W, y: p.y / H) }
            return Quad(tl: n(minus(minus(centre, hw), hh)), tr: n(minus(plus(centre, hw), hh)),
                        br: n(plus(plus(centre, hw), hh)), bl: n(plus(minus(centre, hw), hh)))
        }
        // The text's own angle in this frame: a robust line through the bottom (and top) of the ink
        // in each column, sampled along the text. Descenders and accents are outvoted.
        guard base.right - base.left >= 6 else { return nil }
        let every = max(1, (base.right - base.left) / 80)
        var bottoms: [(CGFloat, CGFloat)] = [], tops: [(CGFloat, CGFloat)] = []
        for c in stride(from: base.left, through: base.right, by: every) where base.colInk[c] > 0 {
            var lo = -1, hi = -1
            for row in base.top...base.bottom where base.bits[row * base.cols + c] {
                if lo < 0 { lo = row }
                hi = row
            }
            guard lo >= 0 else { continue }
            bottoms.append((CGFloat(c), CGFloat(hi)))
            tops.append((CGFloat(c), CGFloat(lo)))
        }
        guard bottoms.count >= 6 else { return nil }
        let topAngle = atan(theilSen(tops)) * 180 / .pi
        let bottomAngle = atan(theilSen(bottoms)) * 180 / .pi
        let degrees = (topAngle + bottomAngle) / 2
        if ProcessInfo.processInfo.environment["MASKE_DEBUG"] != nil {
            print(String(format: "    frame: vision angle %.1f°, text leans %+.2f° in it", atan2(base.ux.y, base.ux.x) * 180 / .pi, degrees))
        }
        // Background print and mixed glyph heights can pull just one edge off the text.
        // Keep the original frame when a turn makes the band taller or cuts off end ink.
        guard abs(topAngle - bottomAngle) < 4,
              abs(degrees) > 0.25, abs(degrees) < 10,
              let level = measureFrame(turned(degrees), in: luma, extend: extend),
              level.u(level.right) - level.u(level.left) + max(2, base.h * 0.08) >= base.u(base.right) - base.u(base.left),
              level.v(level.bottom) - level.v(level.top) < base.v(base.bottom) - base.v(base.top) else { return nil }
        return (level, degrees)
    }

    /// The median of the slopes between all pairs of points: a line fit that ignores the odd descender.
    static func theilSen(_ p: [(CGFloat, CGFloat)]) -> CGFloat {
        var slopes: [CGFloat] = []
        for i in 0..<p.count { for j in (i + 1)..<p.count where abs(p[j].0 - p[i].0) > 0.5 { slopes.append((p[j].1 - p[i].1) / (p[j].0 - p[i].0)) } }
        guard !slopes.isEmpty else { return 0 }
        slopes.sort()
        return slopes[slopes.count / 2]
    }

    static func measureFrame(_ quad: Quad, in luma: Luma, extend: Bool = true) -> Ink? {
        let W = CGFloat(luma.width), H = CGFloat(luma.height)
        func px(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * W, y: p.y * H) }
        let tl = px(quad.tl), tr = px(quad.tr), br = px(quad.br), bl = px(quad.bl)
        let ux = normalize(plus(minus(tr, tl), minus(br, bl)))
        let vy = normalize(plus(minus(bl, tl), minus(br, tr)))
        let w = (dist(tl, tr) + dist(bl, br)) / 2
        let h = (dist(tl, bl) + dist(tr, br)) / 2
        guard w >= 4, h >= 4 else { return nil }
        let step = max(0.5, h / 28)
        func point(_ u: CGFloat, _ v: CGFloat) -> CGPoint { plus(plus(tl, scale(ux, u)), scale(vy, v)) }

        // Sample a window a little larger than the box.
        let u0 = -0.9 * h, u1 = w + 0.9 * h, v0 = -0.45 * h, v1 = 1.45 * h
        let cols = Int(((u1 - u0) / step).rounded(.up)), rows = Int(((v1 - v0) / step).rounded(.up))
        guard cols > 2, rows > 2, cols * rows < 4_000_000 else { return nil }
        var grey = [UInt8](repeating: 0, count: cols * rows)
        for r in 0..<rows {
            let v = v0 + CGFloat(r) * step
            for c in 0..<cols {
                let p = point(u0 + CGFloat(c) * step, v)
                grey[r * cols + c] = luma.at(p.x, p.y)
            }
        }
        func col(_ u: CGFloat) -> Int { Int(((u - u0) / step).rounded()) }
        func row(_ v: CGFloat) -> Int { Int(((v - v0) / step).rounded()) }
        let coreC = max(0, col(0))..<min(cols, col(w)), coreR = max(0, row(0))..<min(rows, row(h))
        guard !coreC.isEmpty, !coreR.isEmpty else { return nil }

        // Ink against background, by Otsu's threshold on the box; ink is the minority class.
        var hist = [Int](repeating: 0, count: 256)
        for r in coreR { for c in coreC { hist[Int(grey[r * cols + c])] += 1 } }
        let total = coreR.count * coreC.count
        guard let t = otsu(hist, total) else { return nil }
        let below = hist[0...t].reduce(0, +)
        let darkInk = below <= total - below
        // Too little contrast means no clear text here.
        let (mDark, mLight) = means(hist, t)
        guard mLight - mDark > 28 else { return nil }
        @inline(__always) func ink(_ r: Int, _ c: Int) -> Bool {
            let g = Int(grey[r * cols + c])
            return darkInk ? g <= t : g > t
        }

        // Rows: the band of ink through the middle of the box, allowing small gaps (accents, dots).
        // Two samples are enough: the tail of a comma or a "g" is thin but still ink.
        let rowInk = (0..<rows).map { r in coreC.reduce(0) { $0 + (ink(r, $1) ? 1 : 0) } }
        let rowMin = 2
        guard let seed = (max(0, row(h * 0.2))...min(rows - 1, row(h * 0.8))).max(by: { rowInk[$0] < rowInk[$1] }),
              rowInk[seed] >= rowMin else { return nil }
        let rowGap = max(1, Int((0.14 * h / step).rounded()))
        var top = seed, bottom = seed
        var r = seed - 1, gap = 0
        while r >= 0 { if rowInk[r] >= rowMin { top = r; gap = 0 } else { gap += 1; if gap > rowGap { break } }; r -= 1 }
        r = seed + 1; gap = 0
        while r < rows { if rowInk[r] >= rowMin { bottom = r; gap = 0 } else { gap += 1; if gap > rowGap { break } }; r += 1 }

        // A band much taller than the OCR line is usually security print or another row.
        // Fall back to the original text box instead of letting those pixels steer the fit.
        guard CGFloat(bottom - top + 1) * step <= h * 1.25 else { return nil }

        // Columns: from the first to the last ink inside the box, then on through ink that runs on
        // past its edges (a character Vision's box cut). Gaps inside a word (even "1 1" in many
        // typefaces) are bridged; a clear word gap ends it. Leaving ink uncovered is worse than a little extra.
        let colInk = (0..<cols).map { c in (top...bottom).reduce(0) { $0 + (ink($1, c) ? 1 : 0) } }
        guard let first = coreC.first(where: { colInk[$0] > 0 }), let last = coreC.last(where: { colInk[$0] > 0 }) else { return nil }
        let wordGap = extend ? max(1, Int((0.35 * h / step).rounded())) : 0
        var left = first, right = last
        var c = first - 1; gap = 0
        while extend, c >= 0 { if colInk[c] > 0 { left = c; gap = 0 } else { gap += 1; if gap > wordGap { break } }; c -= 1 }
        c = last + 1; gap = 0
        while extend, c < cols { if colInk[c] > 0 { right = c; gap = 0 } else { gap += 1; if gap > wordGap { break } }; c += 1 }

        var bits = [Bool](repeating: false, count: cols * rows)
        for rr in 0..<rows { for cc in 0..<cols where ink(rr, cc) { bits[rr * cols + cc] = true } }
        return Ink(origin: tl, ux: ux, vy: vy, w: w, h: h, step: step, u0: u0, v0: v0, colInk: colInk,
                   top: top, bottom: bottom, left: left, right: right, size: CGSize(width: W, height: H),
                   bits: bits, cols: cols, rows: rows)
    }

    /// The tight shape around the text in `quad`. `words` keeps only that many clearly separated ink words
    /// from the start (or, with `fromEnd`, the end): for a value whose box also took in a label.
    static func fit(_ quad: Quad, in luma: Luma, margin: CGFloat = 0.12, words: (count: Int, fromEnd: Bool)? = nil, extend: Bool = true) -> Quad? {
        guard let ink = measure(quad, in: luma, extend: extend) else { return nil }
        let l = ink.left, r = ink.right
        if !extend, ProcessInfo.processInfo.environment["MASKE_DEBUG"] != nil {
            print("    refit: w \(Int(ink.w)) h \(Int(ink.h)) step \(ink.step) u0 \(Int(ink.u0)) ink cols \(l)...\(r) = u \(Int(ink.u(l)))...\(Int(ink.u(r))) colInk head \(Array(ink.colInk[max(0,l-8)..<min(ink.colInk.count, l+8)]))")
        }
        if let words, words.count > 0 {
            let runs = ink.runs(gap: 0.6 * ink.h)
            if runs.count > words.count {
                let kept = words.fromEnd ? Array(runs.suffix(words.count)) : Array(runs.prefix(words.count))
                return refined(ink, kept.first!.0, kept.last!.1, in: luma, margin: margin)
            }
        }
        // A fit that keeps much less than the box is not trusted.
        guard words != nil || CGFloat(r - l) * ink.step > 0.2 * ink.w || CGFloat(r - l) * ink.step > 1.5 * ink.h else { return nil }
        return ink.quad(l, r, margin: margin)
    }

    /// Part of a line: the ink after (or before) the gap nearest to where the part should begin
    /// (or end), `boundary` being that place as a share of the line's text. Nil when no gap is near it.
    static func fitPart(of line: Quad, in luma: Luma, boundary: CGFloat, cut: CGPoint?, keepEnd: Bool, margin: CGFloat = 0.12) -> Quad? {
        guard let ink = measure(line, in: luma), ink.right > ink.left else { return nil }
        // Gaps between characters at least as wide as a narrow space.
        let runs = ink.runs(gap: 0.15 * ink.h)
        guard runs.count >= 2 else { return nil }
        let target = cut.map { ink.column(at: $0) }
            ?? (CGFloat(ink.left) + boundary * CGFloat(ink.right - ink.left))
        if ProcessInfo.processInfo.environment["MASKE_DEBUG"] != nil {
            print("    cut: ink \(ink.left)...\(ink.right) boundary \(boundary) target \(Int(target)) runs \(runs)")
        }
        var best: (index: Int, distance: CGFloat)?
        for i in 0..<(runs.count - 1) {
            let centre = CGFloat(runs[i].1 + runs[i + 1].0) / 2
            let d = abs(centre - target)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        guard let best, best.distance * ink.step <= max(1.2 * ink.h, 0.08 * CGFloat(ink.right - ink.left) * ink.step) else { return nil }
        if ProcessInfo.processInfo.environment["MASKE_DEBUG"] != nil {
            let l = keepEnd ? runs[best.index + 1].0 : ink.left, r = keepEnd ? ink.right : runs[best.index].1
            let b = ink.band(l, r)
            print("    ink: h \(Int(ink.h))px step \(ink.step) rows \(ink.top)...\(ink.bottom) band \(b.0)...\(b.1) runs \(runs.count) cols \(l)...\(r)")
            let rowInk = (ink.top...ink.bottom).map { row in (l...r).reduce(0) { $0 + (ink.bits[row * ink.cols + $1] ? 1 : 0) } }
            print("    rowInk: \(rowInk)")
        }
        let (l, r) = keepEnd ? (runs[best.index + 1].0, ink.right) : (ink.left, runs[best.index].1)
        return refined(ink, l, r, in: luma, margin: margin)
    }

    /// Columns `l...r` of a line measured again on their own (their angle and height, not a label's),
    /// unless that loses any of their width: then the line's own measurement is kept.
    static func refined(_ ink: Ink, _ l: Int, _ r: Int, in luma: Luma, margin: CGFloat) -> Quad {
        let plain = ink.quad(l, r, margin: margin)
        guard let own = fit(ink.region(l, r), in: luma, margin: margin, extend: false) else { return plain }
        let width = { (q: Quad) in (dist(q.tl, q.tr) + dist(q.bl, q.br)) / 2 }
        let scaleX = CGSize(width: ink.size.width, height: ink.size.height)
        func px(_ q: Quad) -> Quad { q.mapped { CGPoint(x: $0.x * scaleX.width, y: $0.y * scaleX.height) } }
        return width(px(own)) + 1 >= width(px(plain)) ? own : plain
    }

    /// Roughly how wide a character is, in units of the text height, by script.
    static func advance(_ ch: Character) -> CGFloat {
        guard let s = ch.unicodeScalars.first?.value else { return 0.6 }
        if (0x3040...0x30FF).contains(s) || (0x4E00...0x9FFF).contains(s) || (0xAC00...0xD7AF).contains(s) || (0xFF00...0xFFEF).contains(s) { return 1.0 }
        if ch.isWhitespace { return 0.3 }
        if ch.isUppercase || ch.isNumber { return 0.65 }
        if ch.isLowercase { return 0.52 }
        return 0.32
    }

    static func otsu(_ hist: [Int], _ total: Int) -> Int? {
        guard total > 0 else { return nil }
        let sum = hist.enumerated().reduce(0.0) { $0 + Double($1.offset * $1.element) }
        var sumB = 0.0, wB = 0, best = 0.0, threshold: Int?
        for t in 0..<256 {
            wB += hist[t]
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }
            sumB += Double(t * hist[t])
            let mB = sumB / Double(wB), mF = (sum - sumB) / Double(wF)
            let between = Double(wB) * Double(wF) * (mB - mF) * (mB - mF)
            if between > best { best = between; threshold = t }
        }
        return threshold
    }

    static func means(_ hist: [Int], _ t: Int) -> (Double, Double) {
        var s0 = 0.0, n0 = 0.0, s1 = 0.0, n1 = 0.0
        for (g, n) in hist.enumerated() {
            if g <= t { s0 += Double(g * n); n0 += Double(n) } else { s1 += Double(g * n); n1 += Double(n) }
        }
        return (n0 > 0 ? s0 / n0 : 0, n1 > 0 ? s1 / n1 : 255)
    }
}
