import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var session: Session
    @State private var scanning = false
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 40)

            Mark(size: 60)
                .padding(.bottom, 28)
            Text("Maske")
                .font(.system(size: 46, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(Color.ink)
            Text("Share a copy of your ID, without the parts nobody needs.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 40)

            VStack(spacing: 12) {
                Button {
                    scanning = true
                } label: {
                    Label("Scan document", systemImage: "doc.viewfinder")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.paper)
                }
                .buttonStyle(.borderedProminent)
                .tint(.ink)
                .disabled(!DocumentScanner.isAvailable)

                PhotosPicker(selection: $photos, maxSelectionCount: 2, matching: .images) {
                    Label("Choose photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.ink)
                }
                .buttonStyle(.bordered)
                .tint(.ink)

                Button {
                    importing = true
                } label: {
                    Label("Choose a file", systemImage: "folder")
                        .foregroundStyle(Color.ink)
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
            }
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 12))

            if !DocumentScanner.isAvailable {
                Text("This device has no camera for scanning. Choose a photo or file instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }

            Divider()
                .overlay(Color.hairline)
                .padding(.top, 28)
            HStack {
                Label("Works offline. Nothing is kept.", systemImage: "lock")
                Spacer()
                NavigationLink("Documents", value: Session.Step.supported)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { pages in
                scanning = false
                session.start(with: pages)
            } onCancel: {
                scanning = false
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .pdf]) { result in
            if case .success(let url) = result { session.start(with: Importing.images(fromFile: url)) }
        }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [CGImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data)?.upright() {
                        images.append(image)
                    }
                }
                photos = []
                session.start(with: images)
            }
        }
    }
}
