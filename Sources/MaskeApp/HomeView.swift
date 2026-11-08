import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var scanning = false
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("New copy")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color.ink)
                        .padding(.bottom, 24)
                    Button {
                        scanning = true
                    } label: {
                        SourceRow(title: "Scan document", symbol: "doc.viewfinder")
                    }
                    .disabled(!DocumentScanner.isAvailable)
                    Divider().overlay(Color.hairline)
                    PhotosPicker(selection: $photos, maxSelectionCount: 2, matching: .images) {
                        SourceRow(title: "Choose photos", symbol: "photo.on.rectangle")
                    }
                    Divider().overlay(Color.hairline)
                    Button {
                        importing = true
                    } label: {
                        SourceRow(title: "Choose a file", symbol: "folder")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                if textSize.isAccessibilitySize { privacyNote }
            }
            if !textSize.isAccessibilitySize { privacyNote }
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Maske")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Session.Step.supported) {
                    Label("Documents", systemImage: "globe.europe.africa")
                }
            }
        }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { images in
                scanning = false
                session.importImages {
                    await Task.detached {
                        let pages = images.compactMap { $0.upright() }
                        return pages.count == images.count ? pages : []
                    }.value
                }
            } onCancel: {
                scanning = false
            } onError: {
                scanning = false
                session.importFailed = true
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

    private var privacyNote: some View {
        Label("On-device", systemImage: "lock")
            .font(.footnote)
            .foregroundStyle(Color.muted)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
