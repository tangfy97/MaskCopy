import CoreGraphics
import Foundation

/// What a box on the document hides.
public enum FindingKind: String, Codable, CaseIterable, Sendable {
    case photo
    case personalNumber
    case documentNumber
    case machineReadableZone
    case barcode
    case address
    case cardAccessNumber
    case custom

    /// Order in the review list.
    public static let displayOrder: [FindingKind] = [
        .photo, .personalNumber, .documentNumber, .cardAccessNumber, .address, .machineReadableZone, .barcode, .custom,
    ]
}

/// A suggested (or user-drawn) box. `rect` is normalized to the page, origin top-left; `quad`,
/// when there is one, is the exact (possibly tilted) shape inside it.
public struct Finding: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: FindingKind
    public var rect: CGRect
    public var quad: Quad?
    public var isOn: Bool
    /// The rule that produced it, e.g. "NO fødselsnummer". For the CLI; never shown in the shared copy.
    public var note: String

    public init(id: UUID = UUID(), kind: FindingKind, rect: CGRect, quad: Quad? = nil, isOn: Bool = true, note: String = "") {
        self.id = id
        self.kind = kind
        self.rect = rect
        self.quad = quad
        self.isOn = isOn
        self.note = note
    }

    public init(kind: FindingKind, quad: Quad, note: String = "") {
        self.init(kind: kind, rect: quad.boundingRect, quad: quad, note: note)
    }

    /// The shape that is painted over.
    public var shape: Quad { quad ?? Quad(rect) }

    public func contains(_ p: CGPoint) -> Bool { shape.contains(p) }
}

public enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case passport, idCard, residencePermit, drivingLicence, unknown
}

public struct PageAnalysis: Sendable {
    public var kind: DocumentKind
    public var country: Country?
    public var mrz: MRZ?
    public var findings: [Finding]
    /// Recognized text, for the CLI.
    public var lines: [String]
}

extension CGRect {
    /// Vision's normalized rects have their origin at the bottom left.
    var flippedVertically: CGRect { CGRect(x: minX, y: 1 - maxY, width: width, height: height) }

    func intersectionArea(_ other: CGRect) -> CGFloat {
        let i = intersection(other)
        return i.isNull ? 0 : i.width * i.height
    }

    var area: CGFloat { width * height }

    func clampedToUnit() -> CGRect {
        let x0 = max(0, minX), y0 = max(0, minY), x1 = min(1, maxX), y1 = min(1, maxY)
        return CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
    }
}
