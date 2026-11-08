import SwiftUI
import UIKit

/// A quiet palette: paper, ink and one cold blue. Everything else is the system's.
extension Color {
    static let paper = Color(light: 0xF3F5F3, dark: 0x121B1E)
    static let ink = Color(light: 0x1C2B30, dark: 0xEDF2F1)
    static let hairline = Color(light: 0xD8E0DD, dark: 0x344247)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C292D)
    static let fjord = Color(light: 0x365963, dark: 0xB1C9CE)
    static let muted = Color(light: 0x586A70, dark: 0xA6B8BB)
    /// Masks look the same in light and dark mode: they are what the shared copy will show.
    static let mask = Color(cgColor: Renderer.maskColor)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let v = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
}

/// Shared controls stay native; the document provides the visual content.
struct SourceRow: View {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.dynamicTypeSize) private var textSize
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: 18) {
            if !textSize.isAccessibilitySize {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.fjord.opacity(enabled ? 1 : 0.35))
                    .frame(width: 30)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.ink.opacity(enabled ? 1 : 0.4))
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 22)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}

struct DetailRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        if textSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                content.accessibilityLabel(Text(title))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LabeledContent(title) { content }
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.fjord)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.paper)
            .overlay(alignment: .top) { Color.hairline.frame(height: 0.5) }
    }
}

struct ZoomControls: View {
    @Binding var zoom: CGFloat
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "minus.magnifyingglass").font(.system(size: 20)).accessibilityHidden(true)
            Slider(value: $zoom, in: 1...8)
                .accessibilityLabel("Zoom")
                .accessibilityValue("\(Int(zoom * 100))%")
            Image(systemName: "plus.magnifyingglass").font(.system(size: 20)).accessibilityHidden(true)
            Text("\(Int(zoom * 100))%")
                .font(.caption)
                .monospacedDigit()
                .fixedSize()
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.fjord)
    }
}

extension View {
    func documentFrame() -> some View {
        clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
    }

    func privacyShield(_ enabled: Bool = true) -> some View {
        modifier(PrivacyShield(enabled: enabled))
    }
}

private struct PrivacyShield: ViewModifier {
    @Environment(\.scenePhase) private var phase
    let enabled: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if enabled && phase != .active {
                ZStack {
                    Color.paper.ignoresSafeArea()
                    Mark(size: 72)
                }
            }
        }
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
