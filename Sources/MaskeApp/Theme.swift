import SwiftUI
import UIKit

/// A quiet palette: paper, ink and one cold blue. Everything else is the system's.
extension Color {
    static let paper = Color(light: 0xF4F3EF, dark: 0x121212)
    static let ink = Color(light: 0x1A1A1A, dark: 0xF1F0EC)
    static let hairline = Color(light: 0xDEDCD5, dark: 0x2C2C2A)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1B)
    static let fjord = Color(light: 0x2F5263, dark: 0x8DB4C6)
    /// Masks look the same in light and dark mode: they are what the shared copy will show.
    static let mask = Color(cgColor: Renderer.maskColor)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let v = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
}

extension FindingKind {
    var title: LocalizedStringKey {
        switch self {
        case .photo: "Photo"
        case .personalNumber: "Personal number"
        case .documentNumber: "Document number"
        case .machineReadableZone: "Machine-readable zone"
        case .barcode: "Barcode"
        case .address: "Address"
        case .cardAccessNumber: "Card access number"
        case .custom: "Your boxes"
        }
    }

    var symbol: String {
        switch self {
        case .photo: "person.crop.square"
        case .personalNumber: "number"
        case .documentNumber: "doc.text"
        case .machineReadableZone: "barcode.viewfinder"
        case .barcode: "barcode"
        case .address: "house"
        case .cardAccessNumber: "wave.3.right"
        case .custom: "rectangle.dashed"
        }
    }
}

extension DocumentKind {
    var title: LocalizedStringKey {
        switch self {
        case .passport: "Passport"
        case .idCard: "ID card"
        case .residencePermit: "Residence permit"
        case .drivingLicence: "Driving licence"
        case .unknown: "Document"
        }
    }

    var shortTitle: LocalizedStringKey {
        switch self {
        case .passport: "Passport"
        case .idCard: "ID"
        case .residencePermit: "Residence"
        case .drivingLicence: "Licence"
        case .unknown: "Document"
        }
    }
}

extension Region {
    var title: LocalizedStringKey {
        switch self {
        case .europe: "Europe"
        case .northAmerica: "North America"
        case .oceania: "Australia and New Zealand"
        case .eastAsia: "East Asia"
        case .southeastAsia: "Southeast Asia"
        case .other: "More"
        }
    }
}

/// The app's mark: a card with one line blacked out.
struct Mark: View {
    var size: CGFloat = 56

    var body: some View {
        let s = size
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                .strokeBorder(Color.ink, lineWidth: s * 0.055)
                .frame(width: s, height: s * 0.66)
            Circle()
                .strokeBorder(Color.ink, lineWidth: s * 0.05)
                .frame(width: s * 0.22, height: s * 0.22)
                .offset(x: s * 0.13, y: s * 0.17)
            RoundedRectangle(cornerRadius: s * 0.025)
                .fill(Color.ink)
                .frame(width: s * 0.42, height: s * 0.11)
                .offset(x: s * 0.45, y: s * 0.18)
            RoundedRectangle(cornerRadius: s * 0.02)
                .fill(Color.ink.opacity(0.35))
                .frame(width: s * 0.32, height: s * 0.05)
                .offset(x: s * 0.45, y: s * 0.38)
        }
        .frame(width: s, height: s * 0.66, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}
