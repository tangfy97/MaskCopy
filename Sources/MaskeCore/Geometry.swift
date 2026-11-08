import CoreGraphics
import Foundation

/// Four corners, normalized to the page with the origin at the top left, in the order
/// top left, top right, bottom right, bottom left of the thing they enclose. Text in a photo
/// taken at an angle is a tilted quadrilateral, not an upright rectangle.
public struct Quad: Codable, Equatable, Sendable {
    public var tl: CGPoint
    public var tr: CGPoint
    public var br: CGPoint
    public var bl: CGPoint

    public init(tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint) {
        self.tl = tl
        self.tr = tr
        self.br = br
        self.bl = bl
    }

    public init(_ r: CGRect) {
        self.init(tl: CGPoint(x: r.minX, y: r.minY), tr: CGPoint(x: r.maxX, y: r.minY),
                  br: CGPoint(x: r.maxX, y: r.maxY), bl: CGPoint(x: r.minX, y: r.maxY))
    }

    public var points: [CGPoint] { [tl, tr, br, bl] }

    /// A perspective transform needs four finite corners forming one convex region.
    var isConvex: Bool {
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return false }
        let turns = (0..<4).map { index -> CGFloat in
            let a = minus(points[(index + 1) % 4], points[index])
            let b = minus(points[(index + 2) % 4], points[(index + 1) % 4])
            return a.x * b.y - a.y * b.x
        }
        return turns.allSatisfy { $0 > 1e-10 } || turns.allSatisfy { $0 < -1e-10 }
    }

    public var boundingRect: CGRect {
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    /// Move the complete mask without changing its shape or letting an edge leave the page.
    public func translated(by delta: CGPoint) -> Quad {
        guard delta.x.isFinite, delta.y.isFinite else { return self }
        let bounds = boundingRect
        let x = min(max(delta.x, -bounds.minX), max(-bounds.minX, 1 - bounds.maxX))
        let y = min(max(delta.y, -bounds.minY), max(-bounds.minY, 1 - bounds.maxY))
        return mapped { CGPoint(x: $0.x + x, y: $0.y + y) }
    }

    /// Area in units where the page is `aspect` wide and 1 high.
    public func area(aspect: CGFloat = 1) -> CGFloat {
        let p = points.map { CGPoint(x: $0.x * aspect, y: $0.y) }
        var s: CGFloat = 0
        for i in 0..<4 { s += p[i].x * p[(i + 1) % 4].y - p[(i + 1) % 4].x * p[i].y }
        return abs(s) / 2
    }

    public func contains(_ p: CGPoint) -> Bool {
        var inside = false
        let pts = points
        var j = 3
        for i in 0..<4 {
            let a = pts[i], b = pts[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// The part between `t0` and `t1` along the reading direction (0 = left edge, 1 = right edge).
    func slice(_ t0: CGFloat, _ t1: CGFloat) -> Quad {
        Quad(tl: lerp(tl, tr, t0), tr: lerp(tl, tr, t1), br: lerp(bl, br, t1), bl: lerp(bl, br, t0))
    }

    /// Grown by `padding` × its own height on every side, along its own axes, so tilted text stays covered.
    func expanded(by padding: CGFloat, aspect: CGFloat) -> Quad {
        // Work where one unit is the same length across and down.
        func toSpace(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * aspect, y: p.y) }
        func fromSpace(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / aspect, y: p.y) }
        let a = toSpace(tl), b = toSpace(tr), c = toSpace(br), d = toSpace(bl)
        let across = normalize(minus(plus(minus(b, a), minus(c, d)), .zero))
        let down = normalize(plus(minus(d, a), minus(c, b)))
        let height = (dist(a, d) + dist(b, c)) / 2
        let m = height * padding
        let dx = scale(across, m), dy = scale(down, m)
        return Quad(tl: fromSpace(minus(minus(a, dx), dy)), tr: fromSpace(minus(plus(b, dx), dy)),
                    br: fromSpace(plus(plus(c, dx), dy)), bl: fromSpace(plus(minus(d, dx), dy)))
    }

    /// Stretched along the reading direction so its left and right edges reach `x0` and `x1`.
    func extendedAcross(to x0: CGFloat, _ x1: CGFloat) -> Quad {
        func extend(_ left: CGPoint, _ right: CGPoint) -> (CGPoint, CGPoint) {
            let dx = right.x - left.x
            guard abs(dx) > 1e-6 else { return (left, right) }
            let t0 = (x0 - left.x) / dx, t1 = (x1 - left.x) / dx
            return (lerp(left, right, min(0, t0)), lerp(left, right, max(1, t1)))
        }
        let top = extend(tl, tr), bottom = extend(bl, br)
        return Quad(tl: top.0, tr: top.1, br: bottom.1, bl: bottom.0)
    }

    public func mapped(_ f: (CGPoint) -> CGPoint) -> Quad { Quad(tl: f(tl), tr: f(tr), br: f(br), bl: f(bl)) }

    /// Intersection over union, sampled on a grid (good enough to compare boxes).
    public func iou(_ other: Quad, samples: Int = 40) -> CGFloat {
        let r = boundingRect.union(other.boundingRect)
        guard r.width > 0, r.height > 0 else { return 0 }
        var both = 0, either = 0
        for i in 0..<samples {
            for j in 0..<samples {
                let p = CGPoint(x: r.minX + r.width * (CGFloat(i) + 0.5) / CGFloat(samples),
                                y: r.minY + r.height * (CGFloat(j) + 0.5) / CGFloat(samples))
                let a = contains(p), b = other.contains(p)
                if a || b { either += 1 }
                if a && b { both += 1 }
            }
        }
        return either > 0 ? CGFloat(both) / CGFloat(either) : 0
    }
}

/// The perspective transform that takes the unit square onto a quadrilateral (Heckbert's square-to-quad).
public struct Homography: Sendable {
    let a, b, c, d, e, f, g, h: CGFloat

    public init(unitSquareTo q: Quad) {
        let (x0, y0, x1, y1, x2, y2, x3, y3) = (q.tl.x, q.tl.y, q.tr.x, q.tr.y, q.br.x, q.br.y, q.bl.x, q.bl.y)
        let dx3 = x0 - x1 + x2 - x3, dy3 = y0 - y1 + y2 - y3
        if abs(dx3) < 1e-9 && abs(dy3) < 1e-9 {
            a = x1 - x0; b = x2 - x1; c = x0
            d = y1 - y0; e = y2 - y1; f = y0
            g = 0; h = 0
        } else {
            let dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2
            let den = dx1 * dy2 - dx2 * dy1
            let gg = (dx3 * dy2 - dx2 * dy3) / den, hh = (dx1 * dy3 - dx3 * dy1) / den
            a = x1 - x0 + gg * x1; b = x3 - x0 + hh * x3; c = x0
            d = y1 - y0 + gg * y1; e = y3 - y0 + hh * y3; f = y0
            g = gg; h = hh
        }
    }

    public func apply(_ p: CGPoint) -> CGPoint {
        let w = g * p.x + h * p.y + 1
        return CGPoint(x: (a * p.x + b * p.y + c) / w, y: (d * p.x + e * p.y + f) / w)
    }

    public func apply(_ q: Quad) -> Quad { q.mapped(apply) }

    /// Maps image points back into the unit square used to construct this transform.
    func unapply(_ p: CGPoint) -> CGPoint? {
        let aa = a - p.x * g, bb = b - p.x * h
        let dd = d - p.y * g, ee = e - p.y * h
        let determinant = aa * ee - bb * dd
        guard abs(determinant) > 1e-12 else { return nil }
        let x = p.x - c, y = p.y - f
        let result = CGPoint(x: (x * ee - bb * y) / determinant, y: (aa * y - x * dd) / determinant)
        return result.x.isFinite && result.y.isFinite ? result : nil
    }
}

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
func plus(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
func minus(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
func scale(_ a: CGPoint, _ s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
func normalize(_ a: CGPoint) -> CGPoint {
    let l = hypot(a.x, a.y)
    return l > 0 ? CGPoint(x: a.x / l, y: a.y / l) : .zero
}
