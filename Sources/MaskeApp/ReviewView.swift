import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var drawing = false

    var body: some View {
        Group {
            if session.analyzing {
                ScrollView {
                    VStack(spacing: 28) {
                        if let image = session.previewImage {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .documentFrame()
                        }
                        ProgressView(session.progressTitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.muted)
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Hide details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(session.analyzing)
        .toolbar {
            if session.analyzing {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { session.finish() } }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { drawing.toggle() }
                    } label: {
                        if drawing { Text("Done").bold() } else { Label("Add box", systemImage: "plus.rectangle.on.rectangle") }
                    }
                }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if drawing {
                    Label("Draw a box", systemImage: "hand.draw")
                        .font(.footnote)
                        .foregroundStyle(Color.fjord)
                }

                ForEach($session.pages) { $page in
                    PageCanvas(page: $page, drawing: drawing)
                }

                if session.kindsPresent.isEmpty { nothingFound }
                else {
                    VStack(spacing: 0) {
                        ForEach(session.kindsPresent, id: \.self) { kind in
                            Toggle(isOn: Binding(get: { session.isOn(kind) }, set: { session.set(kind, on: $0) })) {
                                Label(kind.title, systemImage: kind.symbol)
                            }
                            .accessibilityIdentifier("mask-type-\(kind.rawValue)")
                            .padding(.vertical, 12)
                            if kind != session.kindsPresent.last { Divider() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .contentGroup()
                }
            }
            .padding(20)
        }
        .floatingBar {
            ActionBar {
                Button { withAnimation(FlowMotion.navigation) { session.path.append(.share) } } label: {
                    Text("Continue").frame(maxWidth: .infinity).foregroundStyle(Color.onAccent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.kind.title)
                        if let c = session.country { Text(c.name()) }
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(session.kind.title)
                        if let c = session.country { Text("·"); Text(c.name()) }
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.muted)
            if session.country == nil || session.kind == .unknown {
                Text("Not recognised. Add any missing boxes.")
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
            } else if session.country?.isSupported == false {
                Label("Check all masks", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
            }
        }
    }

    private var nothingFound: some View {
        Label("No masks found", systemImage: "rectangle.dashed")
            .font(.subheadline)
            .foregroundStyle(Color.muted)
    }
}

/// One page with its boxes: solid where hidden, dashed where shown.
struct PageCanvas: View {
    @Binding var page: Session.Page
    let drawing: Bool
    @Namespace private var editorTransition
    @State private var drag: CGRect?
    @State private var editing: Finding?
    @State private var moving: (id: UUID, quad: Quad)?

    var body: some View {
        Image(decorative: page.image, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack(alignment: .topLeading) {
                        Color.clear
                        ForEach($page.findings) { $f in
                            // The exact shape that will be painted: tilted text gets a tilted mask.
                            let shape = MaskShape(quad: f.shape)
                            ZStack {
                                shape.fill(f.isOn ? Color.mask : Color.fjord.opacity(0.08))
                                if !f.isOn {
                                    shape.stroke(Color.fjord, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round, dash: [4, 3]))
                                }
                            }
                            .frame(width: size.width, height: size.height)
                            .contentShape(shape)
                            .onTapGesture { if !drawing { editing = f } }
                            .highPriorityGesture(DragGesture(minimumDistance: 6)
                                .onChanged { value in
                                    if moving?.id != f.id {
                                        moving = (f.id, f.shape)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                                    }
                                    guard let original = moving?.quad else { return }
                                    let quad = original.translated(by: CGPoint(x: value.translation.width / size.width,
                                                                             y: value.translation.height / size.height))
                                    f.quad = quad
                                    f.rect = quad.boundingRect
                                    f.note = "adjusted"
                                }
                                .onEnded { _ in moving = nil }, including: drawing ? .none : .all)
                            .contextMenu {
                                Button("Adjust box", systemImage: "arrow.up.left.and.arrow.down.right") {
                                    editing = f
                                }
                                Button(f.isOn ? "Show" : "Hide", systemImage: f.isOn ? "eye" : "eye.slash") {
                                    f.isOn.toggle()
                                }
                                if f.kind == .custom {
                                    Button("Remove box", systemImage: "trash", role: .destructive) {
                                        page.findings.removeAll { $0.id == f.id }
                                    }
                                }
                            }
                            .accessibilityLabel(Text(f.kind.title))
                            .accessibilityValue(Text(f.isOn ? "Hidden" : "Shown"))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Adjust mask")
                            .accessibilityIdentifier("mask-\(f.kind.rawValue)")
                        }
                        if let d = drag {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.mask.opacity(0.7))
                                .frame(width: d.width, height: d.height)
                                .offset(x: d.minX, y: d.minY)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { v in
                                drag = CGRect(x: min(v.startLocation.x, v.location.x), y: min(v.startLocation.y, v.location.y),
                                              width: abs(v.location.x - v.startLocation.x), height: abs(v.location.y - v.startLocation.y))
                            }
                            .onEnded { _ in
                                if let d = drag, d.width > 8, d.height > 8 {
                                    let n = CGRect(x: d.minX / size.width, y: d.minY / size.height, width: d.width / size.width, height: d.height / size.height)
                                    let finding = Finding(kind: .custom, rect: n, note: "drawn")
                                    page.findings.append(finding)
                                    editing = finding
                                }
                                drag = nil
                            },
                        including: drawing ? .all : .subviews
                    )
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        if !drawing { editing = nearestMask(to: value.location, size: size) }
                    })
                }
            }
            .documentFrame()
            .matchedTransitionSource(id: page.id, in: editorTransition)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("page-canvas")
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(drawing ? Color.fjord : .clear, lineWidth: 2))
            .sheet(item: $editing) { finding in
                MaskEditorView(image: page.image, finding: finding) { updated in
                    if let index = page.findings.firstIndex(where: { $0.id == updated.id }) {
                        page.findings[index] = updated
                    }
                }
                .navigationTransition(.zoom(sourceID: page.id, in: editorTransition))
            }
    }

    /// Small text boxes are often shorter than a fingertip. Extend selection to the
    /// nearest edge without enlarging the actual redaction or stealing nearby fields.
    private func nearestMask(to point: CGPoint, size: CGSize) -> Finding? {
        guard size.width > 0, size.height > 0 else { return nil }
        let candidates = page.findings.map { finding -> (Finding, CGFloat, CGFloat) in
            let quad = finding.shape.mapped { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
                let dx = b.x - a.x, dy = b.y - a.y
                let t = min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / max(1e-8, dx * dx + dy * dy)))
                return dist(point, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
            }
            let gap = quad.contains(point) ? 0 : (0..<4).map { distance(quad.points[$0], quad.points[($0 + 1) % 4]) }.min()!
            return (finding, gap, quad.area())
        }.filter { $0.1 <= 22 }
        return candidates.min {
            abs($0.1 - $1.1) > 0.5 ? $0.1 < $1.1 : $0.2 < $1.2
        }?.0
    }
}

/// A mask's four corners, in the page's normalized coordinates, drawn at the page's size.
struct MaskShape: Shape {
    let quad: Quad

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let pts = quad.points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}
