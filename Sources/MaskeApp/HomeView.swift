import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var session: Session
    @State private var scanning = false
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var pendingScan: ImportSource?
    @State private var scanFailed = false
    @State private var selection: ImportSource?
    @State private var pendingImport: (ImportSource, [Int])?
    @State private var openingFile = false
    @State private var fileTask: Task<Void, Never>?

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
                            .disabled(!DocumentScanner.isAvailable || openingFile)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if openingFile {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { fileTask?.cancel(); openingFile = false }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Session.Step.supported) {
                    Label("Documents", systemImage: "info.circle")
                }
            }
        }
        .fullScreenCover(isPresented: $scanning, onDismiss: finishScan) {
            DocumentScanner { source in
                pendingScan = source
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
                openFile(url)
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { session.importFailed = true }
            }
        }
        .sheet(item: $selection, onDismiss: finishSelection) { source in
            PageSelectionView(source: source) { indices in pendingImport = (source, indices) }
        }
        .onDisappear { fileTask?.cancel(); openingFile = false }
        #if DEBUG
        .task {
            if let path = UserDefaults.standard.string(forKey: "MaskeImportPDF") { openFile(URL(fileURLWithPath: path)) }
        }
        #endif
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            photos = []
            session.importImages {
                var images: [CGImage] = []
                for item in items {
                    guard !Task.isCancelled, let value = try? await item.loadTransferable(type: Data.self) else { return [] }
                    let work = Task.detached { Importing.image(data: value) }
                    let image = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
                    guard let image, !Task.isCancelled else { return [] }
                    images.append(image)
                }
                return images
            }
        }
    }

    private var photoSource: some View {
        PhotosPicker(selection: $photos, maxSelectionCount: Importing.maximumPages, matching: .images) {
            HStack(spacing: 8) {
                SourceGlyph(kind: .photos).frame(width: 22, height: 22)
                Text("Photos")
            }
        }
        .accessibilityLabel("Choose photos")
        .disabled(openingFile)
    }

    private var fileSource: some View {
        Button { importing = true } label: {
            HStack(spacing: 8) {
                if openingFile { ProgressView() }
                else { SourceGlyph(kind: .files).frame(width: 22, height: 22) }
                Text("Files")
            }
        }
        .accessibilityLabel("Choose a file")
        .disabled(openingFile)
    }

    private func finishScan() {
        if scanFailed { scanFailed = false; session.importFailed = true }
        guard let source = pendingScan else { return }
        pendingScan = nil
        choose(source)
    }

    private func choose(_ source: ImportSource) {
        if source.pageCount > Importing.maximumPages { selection = source }
        else { importPages(source, indices: Array(0..<source.pageCount)) }
    }

    private func finishSelection() {
        guard let (source, indices) = pendingImport else { return }
        pendingImport = nil
        importPages(source, indices: indices)
    }

    private func importPages(_ source: ImportSource, indices: [Int]) {
        session.importImages {
            let work = Task.detached { source.images(at: indices) }
            return await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
        }
    }

    private func openFile(_ url: URL) {
        if url.pathExtension.lowercased() != "pdf" {
            session.importImages {
                let work = Task.detached { Importing.images(fromFile: url) }
                return await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            }
            return
        }
        fileTask?.cancel()
        openingFile = true
        fileTask = Task {
            let work = Task.detached { ImportSource(pdf: url) }
            let source = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            guard !Task.isCancelled else { return }
            openingFile = false
            if let source { choose(source) }
            else { session.importFailed = true }
        }
    }
}
