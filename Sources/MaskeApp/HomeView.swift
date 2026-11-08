import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var session: Session
    @State private var scanning = false
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var pendingScan: [UIImage]?
    @State private var scanFailed = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                GlassControls {
                    VStack(spacing: 40) {
                        Spacer(minLength: 32)
                        VStack(spacing: 20) {
                            Button { scanning = true } label: {
                                SourceGlyph(kind: .scan)
                                    .frame(width: 48, height: 48)
                                    .scanControl()
                            }
                            .accessibilityLabel("Scan document")
                            .scanAction()
                            .disabled(!DocumentScanner.isAvailable)
                            Text("Scan").font(.title3.weight(.medium))
                                .foregroundStyle(Color.ink)
                                .accessibilityHidden(true)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) { photoSource; fileSource }
                            VStack(spacing: 16) { photoSource; fileSource }
                        }
                        .font(.subheadline)
                        .secondaryAction()
                        .controlSize(.large)
                        .tint(.fjord)
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("MaskCopy")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Session.Step.supported) {
                    Label("Documents", systemImage: "info.circle")
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
            HStack(spacing: 8) {
                SourceGlyph(kind: .photos).frame(width: 22, height: 22)
                Text("Photos")
            }
        }
        .accessibilityLabel("Choose photos")
    }

    private var fileSource: some View {
        Button { importing = true } label: {
            HStack(spacing: 8) {
                SourceGlyph(kind: .files).frame(width: 22, height: 22)
                Text("Files")
            }
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
