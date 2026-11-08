import SwiftUI

/// The watermark draft has local state. Typing does not invalidate the whole session or render pixels.
struct ShareView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var recipient = ""
    @State private var purpose = ""
    @State private var document: UUID?
    @State private var preparing = false
    @State private var failed = false
    @State private var work: Task<Void, Never>?
    @FocusState private var focus: Field?
    enum Field { case recipient, purpose }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    FlowProgress(step: 1)
                    VStack(alignment: .leading, spacing: 0) {
                        field("Recipient", placeholder: "Who is this copy for?", text: $recipient, field: .recipient)
                        Divider()
                        field("Purpose", placeholder: "What is it for?", text: $purpose, field: .purpose)
                        Divider()
                        Group {
                            if textSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Date").font(.subheadline.weight(.medium))
                                    Text(session.copyDate.formatted(date: .abbreviated, time: .omitted))
                                }
                            } else {
                                LabeledContent("Date", value: session.copyDate.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                            .foregroundStyle(Color.muted)
                            .padding(.vertical, 20)
                    }
                    .padding(.horizontal, 20)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(20)
            }
            .onChange(of: focus) { _, value in
                if let value { withAnimation(FlowMotion.navigation) { scroll.scrollTo(value, anchor: .center) } }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Watermark")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if focus == nil {
                ActionBar {
                    Button(action: preview) {
                        HStack(spacing: 8) {
                            if preparing { ProgressView().tint(Color.paper) }
                            Text(textSize.isAccessibilitySize ? "Preview" : "Preview copy")
                        }
                        .frame(maxWidth: .infinity).foregroundStyle(Color.paper)
                    }
                    .accessibilityLabel("Preview copy")
                    .disabled(recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || preparing)
                }
            }
        }
        .onAppear {
            if document == nil {
                document = session.documentID
                recipient = session.recipient
                purpose = session.purpose
            }
        }
        .onDisappear {
            work?.cancel()
            preparing = false
            if document == session.documentID {
                session.recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
                session.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .alert("Couldn’t prepare copy", isPresented: $failed) {
            Button("Try again", action: preview)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func field(_ title: LocalizedStringKey, placeholder: LocalizedStringKey,
                       text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.muted)
            TextField(placeholder, text: text)
                .focused($focus, equals: field)
                .textInputAutocapitalization(.words)
                .submitLabel(field == .recipient ? .next : .done)
                .onSubmit { focus = field == .recipient ? .purpose : nil }
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier(field == .recipient ? "recipient-field" : "purpose-field")
        }
        .foregroundStyle(Color.ink)
        .padding(.vertical, 20)
        .id(field)
    }

    private func preview() {
        guard !preparing else { return }
        focus = nil
        preparing = true
        work = Task {
            let ready = await session.prepareCopy(recipient: recipient, purpose: purpose)
            guard !Task.isCancelled else { return }
            preparing = false
            if ready { withAnimation(FlowMotion.navigation) { session.path.append(.preview) } }
            else { failed = true }
        }
    }
}

struct ReadyCopyView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var image: CGImage?
    @State private var zoom: CGFloat = 1
    @State private var preparing = false
    @State private var failed = false
    @State private var sharing: SharedCopy?
    @State private var shareTask: Task<Void, Never>?
    private struct SharedCopy: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        VStack(spacing: 0) {
            FlowProgress(step: 2).padding(20)
            if let image = image ?? session.copy {
                DocumentViewport(image: image, zoom: $zoom)
                    .accessibilityIdentifier("copy-viewport")
            }
            ZoomControls(zoom: $zoom).padding(20)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Your copy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { session.finish() } } }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button(action: share) {
                    HStack(spacing: 8) {
                        if preparing { ProgressView().tint(Color.paper) }
                        else if !textSize.isAccessibilitySize { Image(systemName: "square.and.arrow.up") }
                        Text("Share copy")
                    }
                    .frame(maxWidth: .infinity).foregroundStyle(Color.paper)
                }
                .disabled(image == nil || preparing)
            }
        }
        .onAppear { image = session.copy }
        .onDisappear { shareTask?.cancel(); preparing = false }
        .privacyShield()
        .sheet(item: $sharing) { copy in ActivitySheet(file: copy.url).privacyShield() }
        .alert("Couldn’t prepare copy", isPresented: $failed) {
            Button("Try again", action: share)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func share() {
        guard let image, !preparing else { return }
        preparing = true
        let document = session.documentID
        let recipient = session.recipient
        shareTask = Task {
            let work = Task.detached(priority: .userInitiated) { Exporter.writeCopy(image, recipient: recipient) }
            let file = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            guard !Task.isCancelled, document == session.documentID else { if let file { Exporter.discard(file) }; return }
            preparing = false
            if let file { sharing = SharedCopy(url: file) } else { failed = true }
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
