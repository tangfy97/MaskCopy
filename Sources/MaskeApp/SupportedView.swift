import SwiftUI

/// The info page, in three levels: Pro (App Store builds), the four identity documents as tiles, then
/// the countries. What each document has hidden is one level down, on that document's page.
struct SupportedView: View {
    static let kinds: [DocumentKind] = [.passport, .idCard, .residencePermit, .drivingLicence]
    @Environment(\.dynamicTypeSize) private var textSize

    static func count(_ kind: DocumentKind?) -> Int {
        Countries.all.filter { $0.isSupported && (kind.map($0.documents.contains) ?? true) }.count
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ProSection()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Identity documents").font(.headline).foregroundStyle(Color.ink)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Self.kinds, id: \.self) { kind in
                            NavigationLink {
                                DocumentCountriesView(kind: kind)
                            } label: {
                                DocumentTile(kind: kind, count: Self.count(kind))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("document-\(kind.rawValue)")
                        }
                    }
                }

                NavigationLink {
                    DocumentCountriesView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe").font(.title3).foregroundStyle(Color.fjord)
                        Text("\(Self.count(nil)) countries").foregroundStyle(Color.ink)
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.muted)
                    }
                    .padding(16)
                    .contentGroup()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("document-countries")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One identity document: its symbol, its name and the number of countries.
private struct DocumentTile: View {
    let kind: DocumentKind
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: kind.documentSymbol).font(.title2).foregroundStyle(Color.fjord)
                Spacer()
                Text(count, format: .number).monospacedDigit().foregroundStyle(Color.muted)
            }
            Text(kind.documentName).font(.body.weight(.medium)).foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .contentGroup()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension DocumentKind {
    /// What MaskCopy looks for on this kind of document, in the Hide screen's order.
    var hiddenKinds: [FindingKind] {
        switch self {
        case .passport: [.photo, .personalNumber, .documentNumber, .cardAccessNumber, .machineReadableZone]
        case .idCard, .residencePermit:
            [.photo, .personalNumber, .documentNumber, .cardAccessNumber, .address, .machineReadableZone, .barcode]
        case .drivingLicence: [.photo, .personalNumber, .documentNumber, .address, .barcode]
        case .unknown: FindingKind.displayOrder.filter { ![.custom, .accountNumber, .transaction].contains($0) }
        }
    }
}

private struct DocumentCountriesView: View {
    var kind: DocumentKind?
    @State private var query = ""

    private var countries: [Country] {
        Countries.all.filter { country in
            country.isSupported && (kind.map { country.documents.contains($0) } ?? true)
                && (query.isEmpty || country.name().localizedStandardContains(query) || country.code.localizedStandardContains(query))
        }.sorted { $0.name() < $1.name() }
    }

    var body: some View {
        List {
            if let kind, query.isEmpty {
                Section {
                    HiddenSymbols(kinds: kind.hiddenKinds)
                        .listRowBackground(Color.card)
                } header: { Text("Hidden automatically") }
            }
            Section {
                ForEach(countries) { country in
                    NavigationLink(country.name()) {
                        CountryDocumentsView(country: country)
                    }
                    .listRowBackground(Color.card)
                }
            } header: {
                if kind != nil && query.isEmpty { Text("\(countries.count) countries") }
            }
        }
        .overlay {
            if countries.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle(kind?.documentName ?? "Countries")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search countries")
    }
}

private struct CountryDocumentsView: View {
    let country: Country

    var body: some View {
        List {
            Section {
                ForEach(SupportedView.kinds.filter { country.documents.contains($0) }, id: \.self) { document in
                    DocumentTypeLabel(kind: document).listRowBackground(Color.card)
                }
            } footer: { Text("Review every mask before sharing.") }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle(country.name())
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// What is hidden, as a wrapping set of symbol-and-name chips.
private struct HiddenSymbols: View {
    let kinds: [FindingKind]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid(columns: 2)
            grid(columns: 1)
        }
        .padding(.vertical, 4)
    }

    private func grid(columns: Int) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: kinds.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(kinds[start..<min(start + columns, kinds.count)], id: \.self) { kind in
                        Label {
                            Text(kind.title).foregroundStyle(Color.ink).fixedSize()
                        } icon: {
                            Image(systemName: kind.symbol).foregroundStyle(Color.fjord)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}
