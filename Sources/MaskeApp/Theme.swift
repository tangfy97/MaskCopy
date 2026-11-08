import SwiftUI
import UIKit

/// A quiet palette: paper, ink and one cold blue. Everything else is the system's.
extension Color {
    static let paper = Color(light: 0xF5F5F1, dark: 0x141B1F)
    static let ink = Color(light: 0x1C2B30, dark: 0xEDF2F1, highContrastLight: 0x0C171A, highContrastDark: 0xFFFFFF)
    static let hairline = Color(light: 0xD8E0DD, dark: 0x344247, highContrastLight: 0xAEB9B5, highContrastDark: 0x798B91)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C292D)
    static let fjord = Color(light: 0x234E61, dark: 0xA9CDD9, highContrastLight: 0x143949, highContrastDark: 0xD3EAF1)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x141B1F, highContrastLight: 0xFFFFFF, highContrastDark: 0x0C171A)
    static let muted = Color(light: 0x586A70, dark: 0xA6B8BB, highContrastLight: 0x3A4A50, highContrastDark: 0xD4E1E3)
    /// Masks look the same in light and dark mode: they are what the shared copy will show.
    static let mask = Color(cgColor: Renderer.maskColor)

    init(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let v = traits.accessibilityContrast == .high
                ? (isDark ? highContrastDark ?? dark : highContrastLight ?? light)
                : (isDark ? dark : light)
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
}

/// Functional glass stays above content. System styles own vibrancy and touch response.
struct GlassControls<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 16) { content }
        } else { content }
    }
}

struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        GlassControls {
            content
                .primaryAction()
                .controlSize(.large)
                .tint(.fjord)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .modifier(LegacyBarBackground())
    }
}

private struct LegacyBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) { content }
        else { content.background(.bar) }
    }
}

private struct NativeActionStyle: ViewModifier {
    var prominent: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if prominent { content.buttonStyle(.glassProminent) }
            else { content.buttonStyle(.glass) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent) }
            else { content.buttonStyle(.bordered) }
        }
    }
}

private struct FloatingBar<Bar: View>: ViewModifier {
    var bar: Bar
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) { bar }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) { bar }
        }
    }
}

private struct EditorSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            content.background(Color.card, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

private struct ScanActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glassProminent).buttonBorderShape(.circle).tint(.fjord)
        } else { content.buttonStyle(ScanSourceStyle()) }
    }
}

extension View {
    func primaryAction() -> some View { modifier(NativeActionStyle(prominent: true)) }
    func secondaryAction() -> some View { modifier(NativeActionStyle(prominent: false)) }
    func scanAction() -> some View { modifier(ScanActionStyle()) }
    func floatingBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        modifier(FloatingBar(bar: content()))
    }
    func editorSurface() -> some View { modifier(EditorSurface()) }
    func contentGroup() -> some View {
        background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

enum FlowMotion {
    static var navigation: Animation {
        UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.12) : .smooth(duration: 0.34)
    }
}

struct ScanSourceStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ink)
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: configuration.isPressed)
    }
}

/// Three optically aligned source symbols, drawn from one 24-point grid.
struct SourceGlyph: View {
    enum Kind { case scan, photos, files }
    let kind: Kind
    var body: some View {
        GeometryReader { geometry in
            SourceOutline(kind: kind)
                .stroke(style: StrokeStyle(lineWidth: geometry.size.width / 16,
                                           lineCap: .round, lineJoin: .round))
            if kind == .scan {
                Capsule()
                    .frame(width: geometry.size.width * 0.16, height: geometry.size.height * 0.055)
                    .position(x: geometry.size.width * 0.585, y: geometry.size.height * 0.46)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SourceOutline: Shape {
    let kind: SourceGlyph.Kind
    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .scan:
            for points in [[CGPoint(x: 7, y: 3), CGPoint(x: 3, y: 3), CGPoint(x: 3, y: 7)],
                           [CGPoint(x: 17, y: 3), CGPoint(x: 21, y: 3), CGPoint(x: 21, y: 7)],
                           [CGPoint(x: 3, y: 17), CGPoint(x: 3, y: 21), CGPoint(x: 7, y: 21)],
                           [CGPoint(x: 17, y: 21), CGPoint(x: 21, y: 21), CGPoint(x: 21, y: 17)]] {
                p.addLines(points)
            }
            p.addRoundedRect(in: CGRect(x: 6.5, y: 7, width: 11, height: 10), cornerSize: CGSize(width: 1.5, height: 1.5))
            p.addEllipse(in: CGRect(x: 8.5, y: 9.7, width: 2.5, height: 2.5))
            p.move(to: CGPoint(x: 9, y: 14.5)); p.addLine(to: CGPoint(x: 15, y: 14.5))
        case .photos:
            p.addRoundedRect(in: CGRect(x: 3, y: 3.5, width: 18, height: 17), cornerSize: CGSize(width: 2.5, height: 2.5))
            p.addEllipse(in: CGRect(x: 6.5, y: 7, width: 3.5, height: 3.5))
            p.addLines([CGPoint(x: 3.5, y: 17), CGPoint(x: 10, y: 12.5), CGPoint(x: 13, y: 15),
                        CGPoint(x: 16.5, y: 11.5), CGPoint(x: 20.5, y: 15)])
        case .files:
            p.move(to: CGPoint(x: 3, y: 7))
            p.addQuadCurve(to: CGPoint(x: 5, y: 5), control: CGPoint(x: 3, y: 5))
            p.addLine(to: CGPoint(x: 9, y: 5))
            p.addLine(to: CGPoint(x: 11.5, y: 8))
            p.addLine(to: CGPoint(x: 19, y: 8))
            p.addQuadCurve(to: CGPoint(x: 21, y: 10), control: CGPoint(x: 21, y: 8))
            p.addLine(to: CGPoint(x: 21, y: 18))
            p.addQuadCurve(to: CGPoint(x: 19, y: 20), control: CGPoint(x: 21, y: 20))
            p.addLine(to: CGPoint(x: 5, y: 20))
            p.addQuadCurve(to: CGPoint(x: 3, y: 18), control: CGPoint(x: 3, y: 20))
            p.closeSubpath()
            p.move(to: CGPoint(x: 3, y: 10)); p.addLine(to: CGPoint(x: 10, y: 10))
        }
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

private struct ScanControl: ViewModifier {
    @ScaledMetric(relativeTo: .title) private var diameter = 112
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.frame(width: min(diameter, 160), height: min(diameter, 160))
                .foregroundStyle(Color.onAccent)
        } else {
            content
                .frame(width: min(diameter, 160), height: min(diameter, 160))
                .foregroundStyle(Color.paper)
                .background(Color.ink, in: Circle())
        }
    }
}

extension View {
    func scanControl() -> some View { modifier(ScanControl()) }
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
            RoundedRectangle(cornerRadius: s * 0.02)
                .fill(Color.ink.opacity(0.35))
                .frame(width: s * 0.74, height: s * 0.05)
                .offset(x: s * 0.13, y: s * 0.48)
        }
        .frame(width: s, height: s * 0.66, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}
