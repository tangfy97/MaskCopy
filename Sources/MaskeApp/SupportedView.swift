import SwiftUI

/// The info page, read top to bottom: what MaskCopy hides, which documents (with the sides to
/// capture), then the countries for each. Full document names throughout, no flags or abbreviations.
struct SupportedView: View {
    static let kinds: [DocumentKind] = [.passport, .idCard, .residencePermit, .drivingLicence]
    /// The same items, order and symbols as the switches on the Hide screen.
    private static let hidden = FindingKind.displayOrder.filter { $0 != .custom }

    private func count(_ kind: DocumentKind?) -> Int {
        Countries.all.filter { $0.isSupported && (kind.map($0.documents.contains) ?? true) }.count
    }

    var body: some View {
        List {
            Section {
                ForEach(Self.hidden, id: \.self) { kind in
                    Label {
                        Text(kind.title).foregroundStyle(Color.ink)
                    } icon: {
                        Image(systemName: kind.symbol).foregroundStyle(Color.fjord)
                    }
                    .listRowBackground(Color.card)
                }
            } header: { Text("Hidden automatically") }

            Section {
                ForEach(Self.kinds, id: \.self) { kind in
                    NavigationLink {
                        DocumentCountriesView(kind: kind)
                    } label: {
                        LabeledContent {
                            Text(count(kind), format: .number).monospacedDigit().foregroundStyle(Color.muted)
                        } label: { DocumentTypeLabel(kind: kind) }
                    }
                    .listRowBackground(Color.card)
                }
            } header: { Text("Documents") }

            Section {
                NavigationLink {
                    DocumentCountriesView()
                } label: {
                    LabeledContent {
                        Text(count(nil), format: .number).monospacedDigit().foregroundStyle(Color.muted)
                    } label: {
                        Label { Text("All countries").foregroundStyle(Color.ink) } icon: {
                            Image(systemName: "globe").foregroundStyle(Color.fjord)
                        }
                    }
                }
                .listRowBackground(Color.card)
                .accessibilityIdentifier("document-countries")
            } header: { Text("Countries") }
            footer: { Text("Review every mask before sharing.") }

            ProSection()
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
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
            ForEach(countries) { country in
                NavigationLink(country.name()) {
                    CountryDocumentsView(country: country)
                }
                .listRowBackground(Color.card)
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
