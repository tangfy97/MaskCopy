import SwiftUI
import UIKit

/// A short tour shown in full once after installing and once after each update that adds something.
/// It remembers only which tour revision it has shown (`MaskeTourSeen`), on this iPhone.
enum Tour {
    /// Raise this when an update adds something to show; everyone then sees the whole tour again.
    static let current = 3
    static let seenKey = "MaskeTourSeen"
    /// Countries this tour revision adds: the globe lights them last and zooms in on them.
    static let newCountries: Set<String> = ["SA", "EG"]

    enum Scene { case masks, watermark, globe, pro }

    struct Page: Identifiable {
        let id: String
        let scene: Scene
        let title: Text
        let detail: Text
    }

    static var pages: [Page] {
        [
            Page(id: "masks", scene: .masks, title: Text("Covers what they don’t need"),
                 detail: Text("You check every mask before sharing")),
        ] + ProTour.pages + [
            Page(id: "watermark", scene: .watermark, title: Text("Mark who it’s for"),
                 detail: Text("Saved as a flat JPG or PDF")),
            Page(id: "globe", scene: .globe, title: Text("\(Countries.supported.count) countries"),
                 detail: Text("Full list: \(Image(systemName: "info.circle")) on the first screen")),
        ]
    }

    /// The whole tour after installing and after every update that raises `current`.
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
                TourPageView(page: page, active: index == offset).tag(offset)
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
    let active: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 8)
                    Group {
                        switch page.scene {
                        case .masks: SpecimenScene(active: active)
                        case .watermark: WatermarkScene(active: active)
                        case .globe: GlobeScene(active: active)
                        case .pro: ProTourScene(active: active)
                        }
                    }
                    .frame(maxWidth: 360)
                    .accessibilityHidden(true)
                    VStack(spacing: 10) {
                        page.title
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        page.detail
                            .font(.body)
                            .foregroundStyle(Color.muted)
                    }
                    .multilineTextAlignment(.center)
                    Spacer(minLength: 72)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Waits, and says whether the scene should go on.
private func hold(_ seconds: Double) async -> Bool {
    try? await Task.sleep(for: .seconds(seconds))
    return !Task.isCancelled
}

// MARK: Official specimens

/// An official specimen and the masks MaskCopy's engine made for it (`maske tour`, see docs/DESIGN.md).
private struct Specimen: Identifiable {
    let id: String
    let image: UIImage
    let masks: [Finding]

    var aspect: CGFloat { image.size.width / max(image.size.height, 1) }

    /// Current official specimens (see NOTICE): United States passport (2021 Next Generation), Norwegian
    /// passport (2026), Chinese passport (2018), California driver licence and Dutch passport (2021),
    /// shown flat and unaltered. The Dutch one comes last: the watermark scene uses it.
    static let all: [Specimen] = ["us-passport-ng", "no-passport-2026", "cn-passport-2018", "us-ca-licence", "nl-passport-2021"]
        .compactMap(load)

    private static let order: [FindingKind] = [.photo, .documentNumber, .personalNumber, .address, .machineReadableZone]

    static func load(_ name: String) -> Specimen? {
        guard let imageURL = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: imageURL.path),
              let masksURL = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: masksURL),
              let masks = try? JSONDecoder().decode([Finding].self, from: data) else { return nil }
        let rank = { (f: Finding) in order.firstIndex(of: f.kind) ?? order.count }
        let sorted = masks.sorted { (rank($0), $0.shape.tl.y) < (rank($1), $1.shape.tl.y) }
        return Specimen(id: name, image: image, masks: sorted)
    }
}

/// One mask, drawn exactly where the engine put it.
private struct QuadShape: Shape {
    let quad: Quad

    func path(in rect: CGRect) -> Path {
        let p = { (point: CGPoint) in CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height) }
        var path = Path()
        path.move(to: p(quad.tl))
        path.addLine(to: p(quad.tr))
        path.addLine(to: p(quad.br))
        path.addLine(to: p(quad.bl))
        path.closeSubpath()
        return path
    }
}

private struct SpecimenCard: View {
    let specimen: Specimen
    var shown: Int

    var body: some View {
        Image(uiImage: specimen.image)
            .resizable()
            .aspectRatio(specimen.aspect, contentMode: .fit)
            .overlay {
                ForEach(Array(specimen.masks.enumerated()), id: \.element.id) { offset, mask in
                    let quad = mask.shape
                    // Each mask grows from its leading edge, the way it is read.
                    QuadShape(quad: quad)
                        .fill(Color.mask)
                        .scaleEffect(x: offset < shown ? 1 : 0.001, y: 1,
                                     anchor: UnitPoint(x: min(quad.tl.x, quad.bl.x), y: (quad.tl.y + quad.bl.y) / 2))
                        .opacity(offset < shown ? 1 : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }
}

/// Each specimen fades in flat and unaltered, then its masks are painted in as level rectangles.
private struct SpecimenScene: View {
    let active: Bool
    @State private var index = 0
    @State private var shown = 0
    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let specimens = Specimen.all

    var body: some View {
        ZStack {
            if specimens.indices.contains(index) {
                SpecimenCard(specimen: specimens[index], shown: reduceMotion ? .max : shown)
                    .offset(y: settled ? 0 : 12)
                    .opacity(settled ? 1 : 0)
                    .id(specimens[index].id)
            }
        }
        .frame(height: 250)
        .task(id: active) {
            guard active, !specimens.isEmpty else { return }
            if reduceMotion { settled = true; return }
            while !Task.isCancelled {
                for i in specimens.indices {
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { index = i; shown = 0; settled = false }
                    guard await hold(0.05) else { return }
                    withAnimation(.easeOut(duration: 0.5)) { settled = true }
                    guard await hold(0.7) else { return }
                    for m in specimens[i].masks.indices {
                        withAnimation(.spring(duration: 0.42, bounce: 0.12)) { shown = m + 1 }
                        guard await hold(0.38) else { return }
                    }
                    guard await hold(1.7) else { return }
                    withAnimation(.easeIn(duration: 0.3)) { settled = false }
                    guard await hold(0.35) else { return }
                }
            }
        }
    }
}

// MARK: Watermark

/// The Dutch specimen as MaskCopy's own renderer flattens it: masked, then with the watermark burnt in.
private struct WatermarkScene: View {
    let active: Bool
    @State private var masked: UIImage?
    @State private var marked: UIImage?
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                if let masked { Image(uiImage: masked).resizable().scaledToFit() }
                if let marked { Image(uiImage: marked).resizable().scaledToFit().opacity(step >= 1 ? 1 : 0) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
            .frame(height: 220)

            HStack(spacing: 10) {
                format("JPG", selected: true)
                format("PDF", selected: false)
                Image(systemName: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.fjord)
                    .frame(width: 44, height: 34)
                    .background(Color.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.hairline))
            }
            .opacity(step >= 2 ? 1 : 0)
            .offset(y: step >= 2 ? 0 : 12)
        }
        .task { await render() }
        .task(id: active) {
            guard active else { return }
            if reduceMotion { step = 2; return }
            while !Task.isCancelled {
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) { step = 0 }
                guard await hold(1.1) else { return }
                withAnimation(.easeInOut(duration: 0.7)) { step = 1 }
                guard await hold(1.2) else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.2)) { step = 2 }
                guard await hold(3) else { return }
            }
        }
    }

    private func format(_ title: String, selected: Bool) -> some View {
        Text(verbatim: title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? Color.onAccent : Color.ink)
            .frame(width: 64, height: 34)
            .background(selected ? Color.fjord : Color.card, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Color.hairline))
    }

    private func render() async {
        guard masked == nil, let specimen = Specimen.all.last, let source = specimen.image.cgImage else { return }
        let masks = specimen.masks
        let images = await Task.detached(priority: .userInitiated) { () -> (CGImage?, CGImage?) in
            let mark = Watermark(recipient: "Hotel Nord", purpose: "Check-in")
            return (Renderer.render(pages: [(source, masks)], watermark: nil, maxWidth: 760),
                    Renderer.render(pages: [(source, masks)], watermark: mark, maxWidth: 760))
        }.value
        masked = images.0.map { UIImage(cgImage: $0) }
        marked = images.1.map { UIImage(cgImage: $0) }
    }
}

// MARK: Globe

/// A dotted globe (Natural Earth outlines, `scripts/globe.py`): supported countries are lit, it turns
/// from region to region, then zooms in on the countries this update adds.
private struct GlobeScene: View {
    let active: Bool
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !active || reduceMotion)) { context in
            let frame = reduceMotion ? Globe.resting : Globe.frame(at: context.date.timeIntervalSince(start))
            VStack(spacing: 14) {
                Canvas { graphics, size in Globe.draw(frame, in: &graphics, size: size) }
                    .frame(height: 280)
                HStack(spacing: 8) {
                    if frame.stop.isNew { NewBadge() }
                    frame.stop.title
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                }
                .opacity(frame.labelOpacity)
                .frame(minHeight: 28)
            }
        }
        .onChange(of: active) { _, isActive in if isActive { start = .now } }
        .onAppear { start = .now }
    }
}

private enum Globe {
    struct Dot {
        let sinLat, cosLat, lon: Double
        /// 0 not supported, 1 supported, 2 added in this update.
        let group: Int
    }

    struct Stop {
        let lat, lon, zoom: Double
        let title: Text
        var isNew = false
    }

    struct Frame {
        var lat, lon, zoom: Double
        var stop: Stop
        var labelOpacity: Double
        /// 0…1: how far the new countries have lit up.
        var newGlow: Double
        var pulse: Double
    }

    static let dots: [Dot] = {
        guard let url = Bundle.main.url(forResource: "globe", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return [] }
        return rows.compactMap { row in
            guard row.count == 3, let lat = (row[0] as? NSNumber)?.doubleValue, let lon = (row[1] as? NSNumber)?.doubleValue,
                  let code = row[2] as? String else { return nil }
            let group = Tour.newCountries.contains(code) ? 2 : Countries.supported.contains(code) ? 1 : 0
            let φ = lat * .pi / 180
            return Dot(sinLat: sin(φ), cosLat: cos(φ), lon: lon * .pi / 180, group: group)
        }
    }()

    private static func name(_ code: String) -> String { Countries.byCode[code]?.name() ?? code }

    static let stops: [Stop] = [
        Stop(lat: 50, lon: 12, zoom: 1, title: Text("Europe")),
        Stop(lat: 42, lon: -96, zoom: 1, title: Text("North America")),
        Stop(lat: 30, lon: 118, zoom: 1, title: Text("Asia")),
        Stop(lat: -30, lon: 150, zoom: 1, title: Text("Australia and New Zealand")),
        Stop(lat: 25, lon: 38, zoom: 2.1, title: Text(verbatim: "\(name("SA")) · \(name("EG"))"), isNew: true),
    ]

    static let travel = 1.4, pause = 1.5, lastPause = 3.2
    static var cycle: Double { Double(stops.count - 1) * (travel + pause) + pause + lastPause }

    /// Reduce Motion: one still view with Europe, Asia and the new countries lit.
    static var resting: Frame {
        Frame(lat: 32, lon: 40, zoom: 1, stop: stops[stops.count - 1], labelOpacity: 1, newGlow: 1, pulse: 0.5)
    }

    private static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    static func frame(at time: Double) -> Frame {
        let t = time.truncatingRemainder(dividingBy: cycle)
        let first = stops[0]
        if t < pause {
            return Frame(lat: first.lat, lon: first.lon, zoom: first.zoom, stop: first,
                         labelOpacity: min(1, t / 0.3), newGlow: 0, pulse: 0)
        }
        var elapsed = pause
        for i in 1..<stops.count {
            let from = stops[i - 1], to = stops[i]
            let stay = i == stops.count - 1 ? pause + lastPause : pause
            if t < elapsed + travel {
                let x = ease((t - elapsed) / travel)
                var dLon = (to.lon - from.lon).truncatingRemainder(dividingBy: 360)
                if dLon > 180 { dLon -= 360 } else if dLon < -180 { dLon += 360 }
                return Frame(lat: from.lat + (to.lat - from.lat) * x, lon: from.lon + dLon * x,
                             zoom: from.zoom + (to.zoom - from.zoom) * x, stop: x < 0.5 ? from : to,
                             labelOpacity: abs(x - 0.5) * 2, newGlow: to.isNew ? x : 0, pulse: 0)
            }
            elapsed += travel
            if t < elapsed + stay {
                let since = t - elapsed
                return Frame(lat: to.lat, lon: to.lon, zoom: to.zoom, stop: to,
                             labelOpacity: min(1, since / 0.3) * min(1, (elapsed + stay - t) / 0.3),
                             newGlow: to.isNew ? 1 : 0, pulse: to.isNew ? (sin(since * 3.4) + 1) / 2 : 0)
            }
            elapsed += stay
        }
        return resting
    }

    static func draw(_ frame: Frame, in graphics: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 * 0.94 * frame.zoom
        let φ0 = frame.lat * .pi / 180, λ0 = frame.lon * .pi / 180
        let sinφ0 = sin(φ0), cosφ0 = cos(φ0)
        let project = { (dot: Dot) -> (CGPoint, Double)? in
            let dλ = dot.lon - λ0
            let cosDλ = cos(dλ)
            let depth = sinφ0 * dot.sinLat + cosφ0 * dot.cosLat * cosDλ
            guard depth > 0.02 else { return nil }
            return (CGPoint(x: center.x + radius * dot.cosLat * sin(dλ),
                            y: center.y - radius * (cosφ0 * dot.sinLat - sinφ0 * dot.cosLat * cosDλ)), depth)
        }

        graphics.clip(to: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 24))
        let sphere = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        graphics.fill(sphere, with: .radialGradient(Gradient(colors: [Color.fjord.opacity(0.11), Color.fjord.opacity(0.02)]),
                                                   center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.4),
                                                   startRadius: 0, endRadius: radius * 1.3))
        graphics.stroke(sphere, with: .color(Color.fjord.opacity(0.18)), lineWidth: 1)

        let dotRadius = max(1.3, radius / 118)
        let visible = CGRect(origin: .zero, size: size).insetBy(dx: -10, dy: -10)
        // One path per colour and depth band keeps 4000 dots to a handful of fills per frame.
        var paths = Array(repeating: Path(), count: 6)
        var halo = Path()
        for dot in dots {
            guard let (point, depth) = project(dot), visible.contains(point) else { continue }
            let group = dot.group == 2 && frame.newGlow < 0.5 ? 0 : dot.group
            let r = dotRadius * (group == 0 ? 0.8 : 1.0) * (0.55 + 0.45 * depth)
            paths[group * 2 + (depth > 0.35 ? 0 : 1)].addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
            if group == 2 {
                let h = dotRadius * 3.2
                halo.addEllipse(in: CGRect(x: point.x - h, y: point.y - h, width: h * 2, height: h * 2))
            }
        }
        let highlight = Color(red: 0.86, green: 0.47, blue: 0.16)
        if !halo.isEmpty {
            var glow = graphics
            glow.addFilter(.blur(radius: dotRadius * 2.5))
            glow.fill(halo, with: .color(highlight.opacity(0.28 * frame.newGlow * (0.6 + 0.4 * frame.pulse))))
        }
        let colours: [Color] = [Color.muted.opacity(0.45), Color.fjord, highlight]
        for group in 0..<3 {
            let opacity = group == 2 ? frame.newGlow * (0.8 + 0.2 * frame.pulse) : 1
            graphics.fill(paths[group * 2], with: .color(colours[group].opacity(opacity)))
            graphics.fill(paths[group * 2 + 1], with: .color(colours[group].opacity(opacity * 0.45)))
        }
    }
}
