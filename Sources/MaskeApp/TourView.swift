import SwiftUI

/// A short tour shown in full once after installing and once after each update that adds something.
/// It remembers only which tour revision it has shown (`MaskeTourSeen`), on this iPhone.
enum Tour {
    /// Raise this, and give the new pages this release number, when an update adds something to show.
    static let current = 2
    static let seenKey = "MaskeTourSeen"

    struct Page: Identifiable {
        let id: String
        /// The tour revision that added this page.
        let release: Int
        let art: TourArt
        let title: LocalizedStringKey
        var detail: LocalizedStringKey? = nil

        var isNew: Bool { release == Tour.current }
    }

    static let pages: [Page] = [
        Page(id: "scan", release: 1, art: .scan, title: "Scan or choose a document", detail: "Read on your iPhone only"),
        Page(id: "masks", release: 1, art: .masks, title: "Check every mask"),
        Page(id: "watermark", release: 1, art: .watermark, title: "Mark who it’s for"),
        Page(id: "middle-east", release: 2, art: .arabic, title: "Saudi Arabia and Egypt",
             detail: "Passports, ID cards, iqamas and licences"),
        Page(id: "united-states", release: 2, art: .unitedStates, title: "More US documents",
             detail: "Green card, passport card, state ID"),
    ]

    /// The whole tour, after installing and after every update that raises `current`.
    /// Pages added in this release carry the New badge.
    static func pages(seen: Int) -> [Page] {
        seen < current ? pages : []
    }
}

struct TourView: View {
    let pages: [Tour.Page]
    var finish: () -> Void
    @State private var index = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isLast: Bool { index == pages.count - 1 }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { offset, page in
                TourPageView(page: page).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 && !typeSize.isAccessibilitySize ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color.paper.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                if !isLast { Button("Skip", action: finish).tint(.fjord) }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .floatingBar {
            ActionBar {
                Button {
                    if isLast { finish() } else { withAnimation(FlowMotion.navigation) { index += 1 } }
                } label: {
                    Text(isLast ? "Start" : "Continue").frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct TourPageView: View {
    let page: Tour.Page

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)
                    TourArtwork(art: page.art)
                        .frame(maxWidth: 320)
                        .accessibilityHidden(true)
                    VStack(spacing: 12) {
                        if page.isNew { NewBadge() }
                        Text(page.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        if let detail = page.detail {
                            Text(detail)
                                .font(.body)
                                .foregroundStyle(Color.muted)
                        }
                    }
                    .multilineTextAlignment(.center)
                    Spacer(minLength: 72)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
