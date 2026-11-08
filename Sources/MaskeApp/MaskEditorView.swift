import SwiftUI

/// Adjust the actual export polygon at a useful scale, with the document kept in memory.
struct MaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: CGImage
    let finding: Finding
    let save: (Finding) -> Void
    @State private var quad: Quad
    @State private var zoom: CGFloat = 1
    @State private var dragStart: Quad?
    @State private var hidden: Bool

    init(image: CGImage, finding: Finding, save: @escaping (Finding) -> Void) {
        self.image = image
        self.finding = finding
        self.save = save
        _quad = State(initialValue: finding.shape.mapped(Self.clamped))
        _hidden = State(initialValue: finding.isOn)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let width = max(1, geometry.size.width - 32) * zoom
                    let size = CGSize(width: width, height: width * CGFloat(image.height) / CGFloat(image.width))
                    ScrollView([.horizontal, .vertical]) {
                        ZStack(alignment: .topLeading) {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .frame(width: size.width, height: size.height)
                            MaskShape(quad: quad)
                                .fill(Color.mask.opacity(hidden ? 0.35 : 0))
                            MaskShape(quad: quad)
                                .stroke(Color.fjord, style: StrokeStyle(lineWidth: 1.5, dash: hidden ? [] : [4, 3]))
                            ForEach(0..<4) { corner in
                                handle(corner, size: size)
                            }
                        }
                        .frame(width: size.width, height: size.height)
                        .coordinateSpace(name: "maskEditorImage")
                        .padding(16)
                    }
                    .defaultScrollAnchor(.center)
                    .accessibilityIdentifier("mask-editor-canvas")
                }

                VStack(alignment: .leading, spacing: 12) {
                    ZoomControls(zoom: $zoom)
                    HStack {
                        Toggle("Hide", isOn: $hidden)
                            .fixedSize()
                        Spacer()
                        Button("Reset") {
                            quad = finding.shape.mapped(Self.clamped)
                            hidden = finding.isOn
                        }
                    }
                }
                .padding(20)
                .background(Color.card)
            }
            .background(Color.paper)
            .navigationTitle(finding.kind == .photo ? "Adjust photo" : "Adjust box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = finding
                        updated.quad = quad
                        updated.rect = quad.boundingRect
                        updated.isOn = hidden
                        updated.note = "adjusted"
                        save(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
        .privacyShield()
    }

    private func handle(_ index: Int, size: CGSize) -> some View {
        let point = quad.points[index]
        return Circle()
            .fill(Color.card)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(Color.fjord, lineWidth: 2))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .position(x: point.x * size.width, y: point.y * size.height)
            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("maskEditorImage"))
                .onChanged { value in
                    if dragStart == nil { dragStart = quad }
                    var points = quad.points
                    let start = (dragStart ?? quad).points[index]
                    points[index] = Self.clamped(CGPoint(x: start.x + value.translation.width / size.width,
                                                        y: start.y + value.translation.height / size.height))
                    let candidate = Quad(tl: points[0], tr: points[1], br: points[2], bl: points[3])
                    if candidate.isConvex { quad = candidate }
                }
                .onEnded { _ in dragStart = nil })
            .accessibilityLabel(["Top left corner", "Top right corner", "Bottom right corner", "Bottom left corner"][index])
            .accessibilityIdentifier("mask-corner-\(index)")
            .accessibilityValue("\(Int(point.x * 100))% across, \(Int(point.y * 100))% down")
    }

    private static func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
    }
}
