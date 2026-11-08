import SwiftUI
import UIKit

struct ShareView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: CGImage?
    @State private var rendered: PreviewKey?
    @State private var previewFailed = false
    @State private var retry = 0
    @State private var preparing = false
    @State private var exportFailed = false
    @State private var sharing: SharedCopy?
    @State private var previewing = false
    @State private var shareTask: Task<Void, Never>?
    @FocusState private var focus: Field?

    enum Field { case recipient, purpose }
    private struct PreviewKey: Equatable {
        var recipient: String
        var purpose: String
        var document: UUID
        var pages: [UUID]
        var retry: Int
    }
    private struct SharedCopy: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var key: PreviewKey {
        PreviewKey(recipient: session.recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                   purpose: session.purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                   document: session.documentID, pages: session.pages.map(\.revision), retry: retry)
    }
    private var ready: Bool { image != nil && rendered == key && !key.recipient.isEmpty }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 28) {
                    if image == nil { preview }
                    else {
                        Button { focus = nil; previewing = true } label: { preview }
                            .buttonStyle(.plain)
                            .disabled(rendered != key)
                            .accessibilityLabel("Preview copy")
                            .accessibilityValue(rendered == key ? "Up to date" : "Updating")
                    }
                    VStack(spacing: 0) {
                        DetailRow(title: "Recipient") {
                            TextField("Required", text: $session.recipient)
                                .focused($focus, equals: .recipient)
                                .submitLabel(.next)
                                .onSubmit { focus = .purpose }
                                .accessibilityIdentifier("recipient-field")
                        }
                        .padding(.vertical, 18)
                        .contentShape(Rectangle())
                        .onTapGesture { focus = .recipient }
                        .id(Field.recipient)
                        Divider().overlay(Color.hairline)
                        DetailRow(title: "Purpose") {
                            TextField("Optional", text: $session.purpose)
                                .focused($focus, equals: .purpose)
                                .submitLabel(.done)
                                .onSubmit { focus = nil }
                                .accessibilityIdentifier("purpose-field")
                        }
                        .padding(.vertical, 18)
                        .contentShape(Rectangle())
                        .onTapGesture { focus = .purpose }
                        .id(Field.purpose)
                    }
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(Color.ink)
                }
                .padding(20)
            }
            .onChange(of: focus) { _, field in
                if let field { reveal(field, using: scroll) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if let focus { reveal(focus, using: scroll) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { session.finish() } }
        }
        .safeAreaInset(edge: .bottom) {
            if focus == nil {
                ActionBar {
                    Button(action: prepareCopy) {
                        HStack(spacing: 8) {
                            if preparing { ProgressView().tint(Color.paper) }
                            else if !textSize.isAccessibilitySize { Image(systemName: "square.and.arrow.up") }
                            Text("Share copy")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.paper)
                    }
                    .disabled(!ready || preparing)
                }
            }
        }
        .task(id: key) { await refreshPreview(for: key) }
        .onDisappear { shareTask?.cancel(); preparing = false }
        .sheet(item: $sharing) { copy in
            ActivitySheet(file: copy.url).privacyShield()
        }
        .sheet(isPresented: $previewing) {
            if let image { CopyPreviewView(image: image) }
        }
        .alert("Couldn’t prepare copy", isPresented: $exportFailed) {
            Button("Try again", action: prepareCopy)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func reveal(_ field: Field, using scroll: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            scroll.scrollTo(field, anchor: .center)
        }
    }

    @ViewBuilder private var preview: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 340)
                .frame(maxWidth: .infinity)
                .documentFrame()
                .overlay(alignment: .bottomTrailing) {
                    Group {
                        if rendered == key { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        else { ProgressView() }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fjord)
                    .padding(10)
                }
        } else {
            VStack(spacing: 12) {
                if previewFailed {
                    Image(systemName: "doc.badge.ellipsis")
                    Text("Preview unavailable")
                    Button("Try again") { retry += 1 }
                } else { ProgressView() }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .foregroundStyle(Color.muted)
        }
    }

    private func refreshPreview(for request: PreviewKey) async {
        previewFailed = false
        do { try await Task.sleep(for: .milliseconds(image == nil ? 0 : 180)) }
        catch { return }
        guard !Task.isCancelled, !session.pages.isEmpty else { return }
        let pages = session.pages
        let result = await Task.detached(priority: .userInitiated) {
            Exporter.preview(pages, recipient: request.recipient.isEmpty ? "…" : request.recipient, purpose: request.purpose)
        }.value
        guard !Task.isCancelled, key == request else { return }
        image = result
        rendered = result == nil ? nil : request
        previewFailed = result == nil
    }

    private func prepareCopy() {
        guard ready, !preparing, let image else { return }
        focus = nil
        preparing = true
        let request = key
        shareTask = Task {
            let work = Task.detached(priority: .userInitiated) { Exporter.writeCopy(image, recipient: request.recipient) }
            let file = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            guard !Task.isCancelled else { if let file { Exporter.discard(file) }; return }
            preparing = false
            guard request == key else { if let file { Exporter.discard(file) }; return }
            if let file { sharing = SharedCopy(url: file) } else { exportFailed = true }
        }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let file: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [file], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct CopyPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let image: CGImage
    @State private var zoom: CGFloat = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let width = max(1, geometry.size.width - 32) * zoom
                    ScrollView([.horizontal, .vertical]) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: width, height: width * CGFloat(image.height) / CGFloat(image.width))
                            .padding(16)
                    }
                    .defaultScrollAnchor(.center)
                }
                ZoomControls(zoom: $zoom).padding(20).background(Color.card)
            }
            .background(Color.paper)
            .navigationTitle("Copy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .privacyShield()
    }
}
