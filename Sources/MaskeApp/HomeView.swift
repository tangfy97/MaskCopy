import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var scanning = false
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var pendingScan: [UIImage]?
    @State private var scanFailed = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 28) {
                        IdentityCardArtwork()
                            .frame(maxWidth: 310)
                            .padding(.horizontal, 24)
                        Text("Make an ID copy")
                            .font(.largeTitle.weight(.semibold))
                            .tracking(-0.8)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: textSize.isAccessibilitySize ? 240 : max(240, geometry.size.height - 260))
                    VStack(spacing: 14) {
                        Button { scanning = true } label: {
                            Group {
                                if textSize.isAccessibilitySize { Text("Scan") }
                                else { Label("Scan document", systemImage: "doc.viewfinder") }
                            }
                            .frame(maxWidth: .infinity).foregroundStyle(Color.paper)
                        }
                        .accessibilityLabel("Scan document")
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!DocumentScanner.isAvailable)
                        Group {
                            if textSize.isAccessibilitySize {
                                VStack(spacing: 12) { photoSource; fileSource }
                            } else {
                                HStack(spacing: 12) { photoSource; fileSource }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        Label("Only on your iPhone", systemImage: "lock")
                            .font(.footnote)
                            .foregroundStyle(Color.muted)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("MaskCopy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Session.Step.supported) {
                    Label("Documents", systemImage: "globe.europe.africa")
                }
            }
        }
        .fullScreenCover(isPresented: $scanning, onDismiss: finishScan) {
            DocumentScanner { images in
                pendingScan = images
                scanning = false
            } onCancel: {
                scanning = false
            } onError: {
                scanFailed = true
                scanning = false
            }
            .ignoresSafeArea()
            .privacyShield()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .pdf]) { result in
            switch result {
            case .success(let url):
                session.importImages { await Task.detached { Importing.images(fromFile: url) }.value }
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { session.importFailed = true }
            }
        }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            photos = []
            session.importImages {
                var data: [Data] = []
                for item in items {
                    guard !Task.isCancelled, let value = try? await item.loadTransferable(type: Data.self) else { return [] }
                    data.append(value)
                }
                return await Task.detached {
                    let images = data.compactMap { UIImage(data: $0)?.upright() }
                    return images.count == data.count ? images : []
                }.value
            }
        }
    }

    private var photoSource: some View {
        PhotosPicker(selection: $photos, maxSelectionCount: 2, matching: .images) {
            Label("Photos", systemImage: "photo").frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Choose photos")
    }

    private var fileSource: some View {
        Button { importing = true } label: {
            Label("Files", systemImage: "folder").frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Choose a file")
    }

    private func finishScan() {
        if scanFailed { scanFailed = false; session.importFailed = true }
        guard let images = pendingScan else { return }
        pendingScan = nil
        session.importImages {
            await Task.detached {
                let pages = images.compactMap { $0.upright() }
                return pages.count == images.count ? pages : []
            }.value
        }
    }

}
