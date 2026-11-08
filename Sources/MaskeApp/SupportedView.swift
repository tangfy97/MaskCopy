import SwiftUI

struct SupportedView: View {
    private let kinds: [DocumentKind] = [.passport, .idCard, .residencePermit, .drivingLicence]

    var body: some View {
        List {
            Section {
                ForEach(kinds, id: \.self) { kind in
                    NavigationLink {
                        DocumentCountriesView(kind: kind)
                    } label: {
                        DocumentTypeLabel(kind: kind)
                    }
                }
            }
            Section {
                NavigationLink {
                    DocumentCountriesView()
                } label: {
                    LabeledContent {
                        Text(Countries.supported.count, format: .number).foregroundStyle(Color.muted)
                    } label: { Label("Countries", systemImage: "globe") }
                }
                .accessibilityIdentifier("document-countries")
            } footer: { Text("Import photos or PDF. Review every mask.") }
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
                    CountryDocumentsView(country: country, kind: kind)
                }
                .listRowBackground(Color.card)
            }
        }
        .overlay {
            if countries.isEmpty {
                ContentUnavailableView.search(text: query)
            }
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
    var kind: DocumentKind?

    var body: some View {
        List {
            Section {
                ForEach(country.documents.filter { kind == nil || $0 == kind }, id: \.self) { document in
                    DocumentTypeLabel(kind: document)
                    .listRowBackground(Color.card)
                }
            } header: { Text("Automatic masking") }
            footer: { Text("Suggestions vary by document version. Review every mask.") }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle(country.name())
        .navigationBarTitleDisplayMode(.inline)
    }
}
