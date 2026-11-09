import SwiftUI

struct PageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    let source: ImportSource
    let use: ([Int]) -> Void
    @State private var selected: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(0..<source.pageCount, id: \.self) { index in
                        Button {
                            if selected.contains(index) { selected.remove(index) }
                            else if selected.count < Importing.maximumPages { selected.insert(index) }
                        } label: {
                            ImportPageLabel(index: index, selected: selected.contains(index)) {
                                ImportThumbnail(source: source, index: index)
                            }
                        }
                        .disabled(!selected.contains(index) && selected.count == Importing.maximumPages)
                        .accessibilityLabel("Page \(index + 1)")
                        .accessibilityValue(selected.contains(index) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("import-page-\(index + 1)")
                    }
                } footer: { Text("Select up to \(Importing.maximumPages) pages.") }
            }
            .accessibilityIdentifier("page-selection")
            .navigationTitle(textSize.isAccessibilitySize ? "Pages" : "Choose pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selected.count))") { use(selected.sorted()); dismiss() }
                        .disabled(selected.isEmpty)
                        .accessibilityIdentifier("import-selected-pages")
                }
            }
        }
        .privacyShield()
    }
}

private struct ImportThumbnail: View {
    let source: ImportSource
    let index: Int
    @State private var image: CGImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit) }
            else if failed { Image(systemName: "doc").foregroundStyle(Color.muted) }
            else { ProgressView() }
        }
        .frame(width: 80, height: 64)
        .accessibilityHidden(true)
        .task {
            let work = Task.detached(priority: .utility) { source.image(at: index, maxSide: 240) }
            let result = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            if !Task.isCancelled { image = result; failed = result == nil }
        }
    }
}
