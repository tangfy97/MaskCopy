import SwiftUI

/// Adjust the actual export polygon at a useful scale, with the document kept in memory.
struct MaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: CGImage
    let finding: Finding
    let save: (Finding) -> Void
    @State private var quad: Quad
    @State private var zoom: CGFloat = 1
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
                DocumentViewport(image: image, zoom: $zoom, quad: $quad, hidden: hidden)
                    .accessibilityIdentifier("mask-editor-canvas")

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

    private static func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
    }
}
