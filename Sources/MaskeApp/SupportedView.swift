import SwiftUI

struct SupportedView: View {
    var body: some View {
        List {
            Section {
                Text("Passports from every country work through the machine-readable zone. The countries below are also checked field by field: personal numbers, document numbers, addresses and barcodes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }
            ForEach(Region.allCases, id: \.self) { region in
                let countries = Countries.all.filter { $0.region == region }.sorted { $0.name() < $1.name() }
                if !countries.isEmpty {
                    Section {
                        ForEach(countries) { c in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(c.flag)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name()).foregroundStyle(Color.ink)
                                    HStack(spacing: 0) {
                                        ForEach(Array(c.documents.enumerated()), id: \.offset) { i, kind in
                                            if i > 0 { Text(" · ") }
                                            Text(kind.shortTitle)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(Color.card)
                        }
                    } header: {
                        HStack {
                            Text(region.title)
                            Spacer()
                            Text("\(countries.count)").monospacedDigit()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
    }
}
