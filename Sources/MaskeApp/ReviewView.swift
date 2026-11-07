import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var session: Session
    @State private var drawing = false

    var body: some View {
        Group {
            if session.analyzing {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Reading the document on your iPhone…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !session.analyzing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { drawing.toggle() }
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

                ForEach($session.pages) { $page in
                    PageCanvas(page: $page, drawing: drawing)
                }

                Text(drawing
                     ? "Drag over anything else you want to hide."
                     : "Tap a box to show or hide what is under it. Check every field before you share.")
                    .font(.footnote)
                    .foregroundStyle(drawing ? Color.fjord : .secondary)
                    .animation(.default, value: drawing)

                if !session.kindsPresent.isEmpty { toggles } else { nothingFound }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                session.path.append(.share)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.paper)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .controlSize(.large)
            .tint(.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.paper.opacity(0.94).ignoresSafeArea())
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let c = session.country { Text(c.flag) }
                Text(session.kind.title)
                if let c = session.country { Text("·").foregroundStyle(.secondary); Text(c.name()) }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.ink)
            if session.country == nil || session.kind == .unknown {
                Text("Not recognised. Maske found what it could; add boxes for the rest.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if session.country?.isSupported == false {
                Text("This country isn’t on Maske’s supported list yet. Check every box carefully.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var toggles: some View {
        VStack(spacing: 0) {
            ForEach(session.kindsPresent, id: \.self) { kind in
                Toggle(isOn: Binding(get: { session.isOn(kind) }, set: { on in withAnimation(.snappy) { session.set(kind, on: on) } })) {
                    Label {
                        HStack(spacing: 6) {
                            Text(kind.title)
                            if session.count(kind) > 1 {
                                Text("\(session.count(kind))").foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    } icon: {
                        Image(systemName: kind.symbol).foregroundStyle(Color.ink.opacity(0.7))
                    }
                }
                .tint(.ink)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                if kind != session.kindsPresent.last {
                    Divider().overlay(Color.hairline).padding(.leading, 52)
                }
            }
        }
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.hairline))
    }

    private var nothingFound: some View {
        Text("Nothing to hide was found. Use Add box to cover anything yourself.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// One page with its boxes: solid where hidden, dashed where shown.
struct PageCanvas: View {
    @Binding var page: Session.Page
    let drawing: Bool
    @State private var drag: CGRect?

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
                            .onTapGesture { withAnimation(.snappy(duration: 0.2)) { f.isOn.toggle() } }
                            .contextMenu {
                                if f.kind == .custom {
                                    Button("Remove box", systemImage: "trash", role: .destructive) {
                                        page.findings.removeAll { $0.id == f.id }
                                    }
                                }
                            }
                            .accessibilityLabel(Text(f.kind.title))
                            .accessibilityValue(Text(f.isOn ? "Hidden" : "Shown"))
                            .accessibilityAddTraits(.isButton)
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
                                    page.findings.append(Finding(kind: .custom, rect: n, note: "drawn"))
                                }
                                drag = nil
                            },
                        including: drawing ? .all : .subviews
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(drawing ? Color.fjord : Color.hairline, lineWidth: drawing ? 2 : 1))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
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
