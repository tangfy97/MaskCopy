import SwiftUI

struct SupportedView: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var query = ""

    var body: some View {
        List {
            ForEach(Region.allCases, id: \.self) { region in
                let countries = Countries.all.filter {
                    $0.region == region && $0.isSupported
                        && (query.isEmpty || $0.name().localizedStandardContains(query) || $0.code.localizedStandardContains(query))
                }.sorted { $0.name() < $1.name() }
                if !countries.isEmpty {
                    Section {
                        ForEach(countries) { c in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(c.flag)
                                    .font(.system(size: 24))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name()).foregroundStyle(Color.ink)
                                    Group {
                                        if textSize.isAccessibilitySize {
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(c.documents, id: \.self) { Text($0.shortTitle) }
                                            }
                                        } else {
                                            HStack(spacing: 0) {
                                                ForEach(Array(c.documents.enumerated()), id: \.offset) { i, kind in
                                                    if i > 0 { Text(" · ") }
                                                    Text(kind.shortTitle)
                                                }
                                            }
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.muted)
                                }
                            }
                            .listRowBackground(Color.card)
                        }
                    } header: { Text(region.title) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Search countries")
    }
}
