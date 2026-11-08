import SwiftUI
import UIKit

/// A quiet palette: paper, ink and one cold blue. Everything else is the system's.
extension Color {
    static let paper = Color(light: 0xF5F5F1, dark: 0x141B1F)
    static let ink = Color(light: 0x1C2B30, dark: 0xEDF2F1)
    static let hairline = Color(light: 0xD8E0DD, dark: 0x344247)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C292D)
    static let fjord = Color(light: 0x234E61, dark: 0xA9CDD9)
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

struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.fjord)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
    }
}

enum FlowMotion {
    static var navigation: Animation {
        UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.12) : .smooth(duration: 0.34)
    }
}

struct FlowProgress: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let step: Int
    private let titles = ["Hide", "Watermark", "Share"]
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(0..<3) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(index <= step ? Color.fjord : Color.hairline).frame(height: 3)
                        if !textSize.isAccessibilitySize {
                            Text(titles[index]).font(.caption.weight(index == step ? .semibold : .regular))
                                .foregroundStyle(index == step ? Color.ink : Color.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if textSize.isAccessibilitySize {
                HStack {
                    Text(titles[step]).foregroundStyle(Color.ink)
                    Spacer()
                    Text("\(step + 1) / 3").monospacedDigit().foregroundStyle(Color.muted)
                }
                .font(.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of 3, \(titles[step])")
    }
}

/// An abstract document, not a stored identity or a third-party illustration.
struct IdentityCardArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18).fill(Color.hairline)
                    .rotationEffect(.degrees(-5)).offset(x: -5, y: 5)
                RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.99))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline, lineWidth: 1))
                VStack(alignment: .leading, spacing: w * 0.09) {
                    HStack {
                        Text("ID").font(.system(size: w * 0.055, weight: .semibold, design: .monospaced))
                        Spacer()
                        Image(systemName: "checkmark.shield").font(.system(size: w * 0.07, weight: .light))
                    }
                    .foregroundStyle(Color(red: 0.14, green: 0.31, blue: 0.38))
                    HStack(alignment: .top, spacing: w * 0.08) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.mask).frame(width: w * 0.23, height: w * 0.29)
                        VStack(alignment: .leading, spacing: w * 0.045) {
                            Capsule().fill(Color.hairline).frame(width: w * 0.35, height: w * 0.018)
                            RoundedRectangle(cornerRadius: 2).fill(Color.mask).frame(width: w * 0.25, height: w * 0.04)
                            Capsule().fill(Color.hairline).frame(width: w * 0.29, height: w * 0.018)
                            RoundedRectangle(cornerRadius: 2).fill(Color.mask).frame(width: w * 0.32, height: w * 0.04)
                        }
                    }
                }
                .padding(w * 0.09)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .accessibilityHidden(true)
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
