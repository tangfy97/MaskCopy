import SwiftUI

/// Adjust the actual export polygon at a useful scale, with the document kept in memory.
struct MaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
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
            DocumentViewport(image: image, zoom: $zoom, quad: $quad, hidden: hidden)
                .accessibilityIdentifier("mask-editor-canvas")
                .floatingBar {
                    VStack(alignment: .leading, spacing: 12) {
                        ZoomControls(zoom: $zoom)
                        if textSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 16) {
                                Toggle("Hide", isOn: $hidden)
                                resetButton
                            }
                        } else {
                            HStack {
                                Toggle("Hide", isOn: $hidden).fixedSize()
                                Spacer()
                                resetButton
                            }
                        }
                    }
                    .padding(20)
                    .editorSurface()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
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

    private var resetButton: some View {
        Button("Reset") {
            quad = finding.shape.mapped(Self.clamped)
            hidden = finding.isOn
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private static func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
    }
}
