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
                    .contentGroup()
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
        .navigationBarTitleDisplayMode(.large)
        .floatingBar {
            if focus == nil {
                ActionBar {
                    Button(action: preview) {
                        HStack(spacing: 8) {
                            if preparing { ProgressView().tint(Color.onAccent) }
                            Text(textSize.isAccessibilitySize ? "Preview" : "Preview copy")
                        }
                        .frame(maxWidth: .infinity).foregroundStyle(Color.onAccent)
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
    @State private var output: Output?
    @State private var outputFile: URL?
    @State private var shareTask: Task<Void, Never>?
    @State private var format = Exporter.Format.jpg
    @State private var saved = false
    @State private var saving = false
    private struct Output: Identifiable {
        let id = UUID()
        let url: URL
        let save: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            if let image = image ?? session.copy {
                DocumentViewport(image: image, zoom: $zoom)
                    .accessibilityIdentifier("copy-viewport")
            }
            ZoomControls(zoom: $zoom).padding(20)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Your copy")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { session.finish() } } }
        .floatingBar {
            ActionBar {
                VStack(spacing: 12) {
                    Picker("File format", selection: $format) {
                        ForEach(Exporter.Format.allCases, id: \.self) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(preparing)
                    if textSize.isAccessibilitySize {
                        VStack(spacing: 12) { saveButton; shareButton }
                    } else {
                        HStack(spacing: 12) { saveButton; shareButton }
                    }
                }
            }
        }
        .onAppear { image = session.copy }
        .onDisappear { shareTask?.cancel(); preparing = false }
        .privacyShield()
        .onChange(of: format) { _, _ in saved = false }
        .sheet(item: $output, onDismiss: discardOutput) { copy in
            Group {
                if copy.save {
                    SaveCopySheet(file: copy.url, onSaved: {
                        saved = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }, onFinish: { output = nil })
                }
                else { ActivitySheet(file: copy.url, onFinish: { output = nil }) }
            }
            .presentationDetents(copy.save || textSize.isAccessibilitySize ? [.large] : [.medium, .large])
            .privacyShield()
        }
        .alert("Couldn’t prepare copy", isPresented: $failed) {
            Button("Try again") { export(saving: saving) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var saveButton: some View {
        Button { export(saving: true) } label: {
            HStack(spacing: 8) {
                if preparing && saving { ProgressView().tint(Color.fjord) }
                else {
                    Image(systemName: saved ? "checkmark" : "square.and.arrow.down")
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(saved ? "Saved" : (format == .jpg ? "Save JPG" : "Save PDF"))
            }
            .frame(maxWidth: .infinity)
        }
        .secondaryAction()
        .accessibilityLabel(saved ? "Saved to Files" : (format == .jpg ? "Save JPG" : "Save PDF"))
        .accessibilityIdentifier(saved ? "copy-saved" : "copy-save")
        .disabled(image == nil || preparing)
    }

    private var shareButton: some View {
        Button { export(saving: false) } label: {
            HStack(spacing: 8) {
                if preparing && !saving { ProgressView().tint(Color.onAccent) }
                else { Image(systemName: "square.and.arrow.up") }
                Text("Share")
            }
            .frame(maxWidth: .infinity).foregroundStyle(Color.onAccent)
        }
        .accessibilityLabel("Share copy")
        .disabled(image == nil || preparing)
    }

    private func discardOutput() {
        if let outputFile { Exporter.discard(outputFile) }
        outputFile = nil
    }

    private func export(saving: Bool) {
        guard let image, !preparing else { return }
        preparing = true
        self.saving = saving
        let document = session.documentID
        let recipient = session.recipient
        let format = format
        shareTask = Task {
            let work = Task.detached(priority: .userInitiated) {
                Exporter.writeCopy(image, recipient: recipient, format: format)
            }
            let file = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            guard !Task.isCancelled, document == session.documentID else { if let file { Exporter.discard(file) }; return }
            preparing = false
            if let file {
                outputFile = file
                output = Output(url: file, save: saving)
            } else { failed = true }
        }
    }
}

private struct SaveCopySheet: UIViewControllerRepresentable {
    let file: URL
    let onSaved: () -> Void
    let onFinish: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onSaved: onSaved, onFinish: onFinish) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSaved: () -> Void
        let onFinish: () -> Void
        init(onSaved: @escaping () -> Void, onFinish: @escaping () -> Void) {
            self.onSaved = onSaved
            self.onFinish = onFinish
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if !urls.isEmpty { onSaved() }
            onFinish()
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onFinish() }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let file: URL
    let onFinish: () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in onFinish() }
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
