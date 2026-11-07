import SwiftUI

struct ShareView: View {
    @EnvironmentObject private var session: Session
    @State private var file: URL?
    @State private var preview: UIImage?
    @FocusState private var focus: Field?

    enum Field { case recipient, purpose }

    private var recipientMissing: Bool { session.recipient.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Group {
                    if let preview {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.card.aspectRatio(1.5, contentMode: .fit).overlay(ProgressView())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.hairline))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                .frame(maxHeight: 300)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    field("Who is this copy for?", text: $session.recipient, prompt: "Landlord, employer, hotel…", focus: .recipient)
                    field("What is it for?", text: $session.purpose, prompt: "Optional, e.g. rental application", focus: .purpose)
                }

                Text("Their name, the purpose and today’s date are written across the whole copy, so it can’t be passed on as yours elsewhere. Hidden parts are painted over, not blurred, and the photo’s location and camera details are removed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Watermark")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actions }
        .task(id: "\(session.recipient)|\(session.purpose)") {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let pages = session.pages
            let recipient = recipientMissing ? "…" : session.recipient
            let purpose = session.purpose
            let result = await Task.detached(priority: .userInitiated) {
                Exporter.export(pages, recipient: recipient, purpose: purpose)
            }.value
            file = result?.0
            preview = result?.1
        }
        .onAppear { if recipientMissing { focus = .recipient } }
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey, focus f: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
            TextField(prompt, text: text)
                .focused($focus, equals: f)
                .submitLabel(f == .recipient ? .next : .done)
                .onSubmit { focus = f == .recipient ? .purpose : nil }
                .textInputAutocapitalization(.words)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(focus == f ? Color.fjord : Color.hairline))
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            if let file, let preview, !recipientMissing {
                ShareLink(item: file, preview: SharePreview("ID copy for \(session.recipient)", image: Image(uiImage: preview))) {
                    Label("Share copy", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.paper)
                }
                .buttonStyle(.borderedProminent)
                .tint(.ink)
            } else {
                Button {} label: {
                    Text(recipientMissing ? "Add who it’s for" : "Preparing…").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.ink)
                .disabled(true)
            }
            Button("Done, forget this document") { session.finish() }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        }
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .background(Color.paper.opacity(0.94).ignoresSafeArea())
    }
}
