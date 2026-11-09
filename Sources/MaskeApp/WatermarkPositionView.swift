import SwiftUI

struct WatermarkPositionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    let pages: [Session.Page]
    let watermark: Watermark
    let save: ([CGPoint]) -> Void
    @State private var positions: [CGPoint]
    @State private var pageIndex = 0
    @State private var preview: Preview?
    @State private var failed = false
    @State private var origin: CGPoint?

    private struct Preview {
        let image: CGImage
        let layers: WatermarkLayers
    }

    init(pages: [Session.Page], watermark: Watermark, save: @escaping ([CGPoint]) -> Void) {
        self.pages = pages
        self.watermark = watermark
        self.save = save
        _positions = State(initialValue: pages.map(\.watermarkPosition))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if pages.count > 1 {
                    Picker("Page", selection: $pageIndex) {
                        ForEach(pages.indices, id: \.self) { Text("Page \($0 + 1)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                }
                if let preview { canvas(preview) }
                else if failed {
                    ContentUnavailableView {
                        Label("Couldn’t open preview", systemImage: "doc")
                    } actions: { Button("Try again") { loadID = UUID() } }
                } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle(textSize.isAccessibilitySize ? "Watermark" : "Watermark position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(positions); dismiss() }.disabled(preview == nil)
                }
            }
            .floatingBar {
                Button("Reset", systemImage: "arrow.counterclockwise") { positions[pageIndex] = CGPoint(x: 0.5, y: 0.5) }
                    .secondaryAction().controlSize(.large).padding(16)
            }
            .task(id: LoadID(page: pageIndex, attempt: loadID)) { await load() }
        }
        .privacyShield()
    }

    @State private var loadID = UUID()
    private struct LoadID: Hashable { let page: Int; let attempt: UUID }

    private func load() async {
        preview = nil
        failed = false
        origin = nil
        guard pages.indices.contains(pageIndex) else { failed = true; return }
        let index = pageIndex, page = pages[pageIndex], watermark = self.watermark
        let work = Task.detached(priority: .userInitiated) { () -> Preview? in
            guard let image = Renderer.render(pages: [(page.image, page.findings)], watermark: nil, maxWidth: 1200),
                  let layers = Renderer.watermarkLayers(watermark, size: CGSize(width: image.width, height: image.height)) else { return nil }
            return Preview(image: image, layers: layers)
        }
        let value = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
        guard !Task.isCancelled, index == pageIndex else { return }
        if let value {
            positions[index] = value.layers.clamped(positions[index])
            preview = value
        } else { failed = true }
    }

    private func canvas(_ preview: Preview) -> some View {
        GeometryReader { geometry in
            let factor = min(max(1, geometry.size.width - 32) / CGFloat(preview.image.width),
                             max(1, geometry.size.height - 32) / CGFloat(preview.image.height))
            let size = CGSize(width: CGFloat(preview.image.width) * factor, height: CGFloat(preview.image.height) * factor)
            let point = positions[pageIndex]
            let shift = CGSize(width: (point.x - 0.5) * size.width, height: (point.y - 0.5) * size.height)
            ZStack(alignment: .topLeading) {
                Image(decorative: preview.image, scale: 1).resizable()
                Image(decorative: preview.layers.dark, scale: 1).resizable()
                    .offset(shift).blendMode(.multiply)
                Image(decorative: preview.layers.light, scale: 1).resizable().offset(shift)
                    .clipShape(RedactionRegions(findings: pages[pageIndex].findings))
                Rectangle().fill(.clear)
                    .watermarkSelectionFrame()
                    .frame(width: preview.layers.bounds.width * size.width, height: preview.layers.bounds.height * size.height)
                    .contentShape(Rectangle())
                    .position(x: point.x * size.width, y: point.y * size.height)
                    .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                        if origin == nil {
                            origin = positions[pageIndex]
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                        }
                        if let origin {
                            positions[pageIndex] = preview.layers.clamped(CGPoint(x: origin.x + value.translation.width / size.width,
                                                                                y: origin.y + value.translation.height / size.height))
                        }
                    }.onEnded { _ in origin = nil })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Watermark position")
                    .accessibilityValue("\(Int(point.x * 100))% across, \(Int(point.y * 100))% down")
                    .accessibilityHint("Drag to move")
                    .accessibilityIdentifier("watermark-position")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: nudge(preview, x: 0, y: -0.01)
                        case .decrement: nudge(preview, x: 0, y: 0.01)
                        @unknown default: break
                        }
                    }
                    .accessibilityAction(named: Text("Move left")) { nudge(preview, x: -0.01, y: 0) }
                    .accessibilityAction(named: Text("Move right")) { nudge(preview, x: 0.01, y: 0) }
                    .accessibilityAction(named: Text("Move up")) { nudge(preview, x: 0, y: -0.01) }
                    .accessibilityAction(named: Text("Move down")) { nudge(preview, x: 0, y: 0.01) }
            }
            .frame(width: size.width, height: size.height)
            .documentFrame()
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private func nudge(_ preview: Preview, x: CGFloat, y: CGFloat) {
        let current = positions[pageIndex]
        positions[pageIndex] = preview.layers.clamped(CGPoint(x: current.x + x, y: current.y + y))
    }
}

private struct RedactionRegions: Shape {
    let findings: [Finding]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for finding in findings where finding.isOn {
            path.addLines(finding.shape.points.map { CGPoint(x: $0.x * rect.width, y: $0.y * rect.height) })
            path.closeSubpath()
        }
        return path
    }
}
