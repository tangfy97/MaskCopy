import CoreGraphics
import Foundation
import MaskeCore
import Vision
import UniformTypeIdentifiers

let usage = """
maske fixtures <dir>          make the synthetic documents and their expected answers
maske eval <dir>              check the engine against them; writes masked copies to <dir>/out
maske analyze <image>         print what the engine finds on one photo
maske review <dir> <out>      straighten and mask every image in <dir>, for looking through
maske warp <dir> <out>        photograph-like copies: tilted, turned, on a table
maske angles <warped dir> [expected.json]
                              compare tilted masks against fixture boxes or the original's masks
"""

/// Share of the field covered by active masks, sampled in the field's own frame.
func coverage(_ field: Quad, _ findings: [Finding]) -> Double {
    let on = findings.filter(\.isOn)
    let toField = Homography(unitSquareTo: field)
    var hits = 0
    for i in 0..<48 {
        for j in 0..<12 {
            let point = toField.apply(CGPoint(x: (CGFloat(i) + 0.5) / 48, y: (CGFloat(j) + 0.5) / 12))
            if on.contains(where: { $0.contains(point) }) { hits += 1 }
        }
    }
    return Double(hits) / (48 * 12)
}

let args = CommandLine.arguments.dropFirst()
guard let command = args.first, let path = args.dropFirst().first else {
    print(usage)
    exit(2)
}
let url = URL(fileURLWithPath: path)

switch command {
case "fixtures":
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var all: [Expected] = []
    for doc in Fixtures.all {
        let (image, expected) = Fixtures.render(doc)
        Fixtures.write(image, to: url.appendingPathComponent(doc.name + ".png"))
        all.append(expected)
    }
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try enc.encode(all).write(to: url.appendingPathComponent("expected.json"))
    print("Wrote \(all.count) documents to \(url.path)")

case "analyze":
    guard let image = Fixtures.load(url) else { print("Can't read \(path)"); exit(1) }
    let (doc, a) = try Analyzer().analyze(photo: image)
    print(String(format: "document found: %@  turns: %d  corners: %@", doc.fillsFrame ? "yes" : "no", doc.quarterTurns,
                 doc.corners.points.map { String(format: "(%.2f,%.2f)", $0.x, $0.y) }.joined(separator: " ")))
    print("kind: \(a.kind.rawValue)  country: \(a.country?.code ?? "?")  mrz: \(a.mrz.map { "\($0.format.rawValue) \($0.documentNumber) valid=\($0.checksumsValid)" } ?? "-")")
    for f in a.findings {
        print(String(format: "  %-20@ x %.3f y %.3f w %.3f h %.3f  %@", f.kind.rawValue as NSString, f.rect.minX, f.rect.minY, f.rect.width, f.rect.height, f.note as NSString))
    }
    print("text:")
    for l in a.lines { print("  | \(l)") }

case "eval":
    let expected = try JSONDecoder().decode([Expected].self, from: Data(contentsOf: url.appendingPathComponent("expected.json")))
    let out = url.appendingPathComponent("out")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    var hidden = 0, toHide = 0, kept = 0, toKeep = 0, docsOK = 0, kindsOK = 0, countriesOK = 0
    var precisions: [Double] = []
    var loosest: [(String, Double)] = []
    var problems: [String] = []
    for e in expected {
        guard let image = Fixtures.load(url.appendingPathComponent(e.name + ".png")) else {
            problems.append("\(e.name): fixture image missing or unreadable")
            continue
        }
        let (doc, analysis) = try Analyzer().analyze(photo: image)
        var a = analysis
        // Expected boxes are in the original image; bring the findings back there.
        let toSource = doc.toSource
        a.findings = a.findings.map { f in Finding(kind: f.kind, quad: toSource.apply(f.shape), note: f.note) }
        var ok = true
        for b in e.hide {
            toHide += 1
            let cov = coverage(Quad(b.rect), a.findings)
            if cov >= 0.98 { hidden += 1 } else { ok = false; problems.append(String(format: "%@: not fully hidden (%.0f%%) %@ “%@”", e.name, cov * 100, b.kind, b.text)) }
        }
        // Precision: how much of each mask lies on what it should hide (with a thin tolerance).
        for f in a.findings where f.isOn {
            var targets = e.hide.filter { $0.kind == f.kind.rawValue }.map(\.rect)
            if f.kind == .machineReadableZone, let first = targets.first { targets = [targets.reduce(first) { $0.union($1) }] }
            guard !targets.isEmpty else { continue }
            let tol = targets.map { $0.height * 0.13 }.max() ?? 0
            let grown = targets.map { $0.insetBy(dx: -tol * 0.6, dy: -tol) }
            let r = f.shape.boundingRect
            guard grown.contains(where: { $0.intersects(r) }) else { continue }
            var inside = 0, total = 0
            for i in 0..<40 { for j in 0..<20 {
                let p = CGPoint(x: r.minX + r.width * (CGFloat(i) + 0.5) / 40, y: r.minY + r.height * (CGFloat(j) + 0.5) / 20)
                guard f.contains(p) else { continue }
                total += 1
                if grown.contains(where: { $0.contains(p) }) { inside += 1 }
            } }
            if total > 0 {
                let prec = Double(inside) / Double(total)
                precisions.append(prec)
                loosest.append(("\(e.name) \(f.kind.rawValue)", prec))
            }
        }
        for b in e.keep {
            toKeep += 1
            if coverage(Quad(b.rect), a.findings) <= 0.1 { kept += 1 } else { ok = false; problems.append("\(e.name): hidden by mistake “\(b.text)”") }
        }
        if a.kind.rawValue == e.kind { kindsOK += 1 } else { problems.append("\(e.name): kind \(a.kind.rawValue), expected \(e.kind)") }
        if a.country?.code == e.country { countriesOK += 1 } else { problems.append("\(e.name): country \(a.country?.code ?? "?"), expected \(e.country)") }
        if ok { docsOK += 1 }
        // Expected ink (green outlines) against the masks (red), on the original image.
        if let o = Warp.overlay(image, expected: e.hide.map { Quad($0.rect) }, found: a.findings.filter(\.isOn).map(\.shape)) {
            Warp.writeJPEG(o, to: out.appendingPathComponent(e.name + "-overlay.jpg"), quality: 0.85)
        }
        if let copy = Renderer.render(pages: [(doc.image, analysis.findings)], watermark: Watermark(recipient: "Test", purpose: e.name)),
           let data = Renderer.jpegData(copy) {
            try data.write(to: out.appendingPathComponent(e.name + ".jpg"))
        }
        print(String(format: "%@ %-14@ %-16@ %@", ok ? "✓" : "✗", e.name as NSString, "\(a.kind.rawValue)/\(a.country?.code ?? "?")" as NSString,
                     a.findings.map { $0.kind.rawValue }.joined(separator: " ") as NSString))
    }
    print("")
    for p in problems { print("  " + p) }
    print("")
    print("Documents fully right: \(docsOK)/\(expected.count)")
    let meanPrec = precisions.isEmpty ? 0 : precisions.reduce(0, +) / Double(precisions.count)
    print(String(format: "Mask precision (share of each mask on its field): mean %.2f, worst %.2f", meanPrec, precisions.min() ?? 0))
    print("Loosest masks:")
    for (n, p) in loosest.sorted(by: { $0.1 < $1.1 }).prefix(8) { print(String(format: "  %.2f  %@", p, n as NSString)) }
    print("Sensitive fields hidden: \(hidden)/\(toHide)   Fields kept visible: \(kept)/\(toKeep)")
    print("Document kind right: \(kindsOK)/\(expected.count)   Country right: \(countriesOK)/\(expected.count)")
    exit(docsOK == expected.count ? 0 : 1)

case "ocr":
    // Debug: straighten, then read the straightened image as it is in memory and after a round trip through PNG.
    guard let image = Fixtures.load(url) else { exit(1) }
    let doc = Rectifier.straighten(image)
    let cg = doc.image
    print("in memory: \(cg.width)x\(cg.height) alpha \(cg.alphaInfo.rawValue) bpc \(cg.bitsPerComponent) space \(cg.colorSpace?.name as String? ?? "?")")
    func count(_ img: CGImage) -> (Int, Int) {
        let r = VNRecognizeTextRequest()
        r.recognitionLevel = .accurate
        r.usesLanguageCorrection = false
        r.automaticallyDetectsLanguage = true
        try? VNImageRequestHandler(cgImage: img, options: [:]).perform([r])
        let lines = (r.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return (lines.count, lines.filter { $0.contains("<<") }.count)
    }
    print("memory:", count(cg))
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("maske-ocr.png")
    Fixtures.write(cg, to: tmp)
    print("png:", count(Fixtures.load(tmp)!))

case "review":
    // Every image straightened and masked, plus a line per image, for looking through by eye.
    guard let outPath = args.dropFirst(2).first else { print(usage); exit(2) }
    let out = URL(fileURLWithPath: outPath)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var report: [String] = []
    for file in Warp.images(in: url) {
        guard let image = Fixtures.load(file) else { continue }
        let (doc, a) = try Analyzer().analyze(photo: image)
        let name = file.deletingPathExtension().lastPathComponent
        if let copy = Renderer.render(pages: [(doc.image, a.findings)], watermark: nil, maxWidth: 1400), let data = Renderer.jpegData(copy, quality: 0.8) {
            try data.write(to: out.appendingPathComponent(name + ".jpg"))
        }
        let kinds = Dictionary(grouping: a.findings, by: \.kind).map { "\($0.key.rawValue)×\($0.value.count)" }.sorted().joined(separator: " ")
        let line = String(format: "%-28@ %-16@ mrz:%@ edges:%@ turns:%d  %@", name as NSString,
                          "\(a.kind.rawValue)/\(a.country?.code ?? "?")" as NSString,
                          (a.mrz.map { $0.checksumsValid ? "ok" : "bad" } ?? "-") as NSString,
                          (doc.fillsFrame ? "yes" : "no") as NSString, doc.quarterTurns, kinds as NSString)
        print(line)
        report.append(line)
    }
    try report.joined(separator: "\n").write(to: out.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)

case "warp":
    guard let outPath = args.dropFirst(2).first else { print(usage); exit(2) }
    let out = URL(fileURLWithPath: outPath)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var records: [WarpRecord] = []
    for file in Warp.images(in: url) {
        guard let image = Fixtures.load(file) else { continue }
        let name = file.deletingPathExtension().lastPathComponent
        for v in Warp.variants {
            guard let (photo, corners) = Warp.make(image, v) else { continue }
            let outName = "\(name)__\(v.name).jpg"
            Warp.writeJPEG(photo, to: out.appendingPathComponent(outName))
            records.append(WarpRecord(file: outName, source: file.path, variant: v.name, corners: corners))
        }
    }
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted]
    try enc.encode(records).write(to: out.appendingPathComponent("warps.json"))
    print("Wrote \(records.count) photo-like copies to \(out.path)")

case "angles":
    // Use drawn field bounds when available; original masks are a consistency check for unlabelled photos.
    let records = try JSONDecoder().decode([WarpRecord].self, from: Data(contentsOf: url.appendingPathComponent("warps.json")))
    var fixtures: [String: Expected]?
    if let expectedPath = args.dropFirst(2).first {
        let labels = try JSONDecoder().decode([Expected].self, from: Data(contentsOf: URL(fileURLWithPath: expectedPath)))
        fixtures = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0) })
    }
    let overlays = url.appendingPathComponent("overlays")
    try FileManager.default.createDirectory(at: overlays, withIntermediateDirectories: true)
    var originals: [String: [Finding]] = [:]
    var stats: [String: (matched: Int, total: Int, iou: Double, extra: Int)] = [:]
    var worst: [(String, Double)] = []
    var hidden = 0, toHide = 0, kept = 0, toKeep = 0
    for r in records {
        let source = URL(fileURLWithPath: r.source)
        let toCopy = Homography(unitSquareTo: r.corners)
        let fixture = fixtures?[source.deletingPathExtension().lastPathComponent]
        if fixtures != nil && fixture == nil {
            print("Missing expected fields for \(r.file)")
            exit(1)
        }
        if fixtures == nil, originals[r.source] == nil, let image = Fixtures.load(source) {
            let (doc, a) = try Analyzer().analyze(photo: image)
            originals[r.source] = a.findings.map { Finding(kind: $0.kind, quad: doc.toSource.apply($0.shape), note: $0.note) }
        }
        guard let photo = Fixtures.load(url.appendingPathComponent(r.file)) else {
            print("Missing or unreadable warped image: \(r.file)")
            exit(1)
        }
        let original: [Finding]
        if let fixture {
            let mrz = fixture.hide.filter { $0.kind == FindingKind.machineReadableZone.rawValue }
            var fields = fixture.hide.filter { $0.kind != FindingKind.machineReadableZone.rawValue }.compactMap { box in
                FindingKind(rawValue: box.kind).map { Finding(kind: $0, rect: box.rect) }
            }
            if let first = mrz.first {
                fields.append(Finding(kind: .machineReadableZone, rect: mrz.dropFirst().reduce(first.rect) { $0.union($1.rect) }))
            }
            original = fields
        } else if let findings = originals[r.source] {
            original = findings
        } else {
            print("Missing or unreadable source image: \(r.source)")
            exit(1)
        }
        let expected = original.map { Finding(kind: $0.kind, quad: toCopy.apply($0.shape)) }
        let (doc, a) = try Analyzer().analyze(photo: photo)
        let found = a.findings.map { Finding(kind: $0.kind, quad: doc.toSource.apply($0.shape)) }
        if let fixture {
            for field in fixture.hide {
                toHide += 1
                let share = coverage(toCopy.apply(Quad(field.rect)), found)
                if share >= 0.98 { hidden += 1 } else {
                    print(String(format: "%@: %@ only %.0f%% covered", r.file, field.kind, share * 100))
                }
            }
            for field in fixture.keep {
                toKeep += 1
                let share = coverage(toCopy.apply(Quad(field.rect)), found)
                if share <= 0.1 { kept += 1 } else {
                    print(String(format: "%@: kept field %.0f%% covered", r.file, share * 100))
                }
            }
        }
        var used = Set<UUID>()
        var docScore = 0.0, docCount = 0
        for e in expected {
            let best = found.filter { $0.kind == e.kind }.map { ($0.id, Double(e.shape.iou($0.shape))) }.max { $0.1 < $1.1 }
            var st = stats[e.kind.rawValue] ?? (0, 0, 0, 0)
            st.total += 1
            st.iou += best?.1 ?? 0
            if let best, best.1 >= 0.5 { st.matched += 1; used.insert(best.0) }
            stats[e.kind.rawValue] = st
            docScore += best?.1 ?? 0
            docCount += 1
        }
        for f in found where !used.contains(f.id) {
            var st = stats[f.kind.rawValue] ?? (0, 0, 0, 0)
            st.extra += 1
            stats[f.kind.rawValue] = st
        }
        let mean = docCount > 0 ? docScore / Double(docCount) : 1
        worst.append((r.file, mean))
        if let o = Warp.overlay(photo, expected: expected.map(\.shape), found: found.map(\.shape)) {
            Warp.writeJPEG(o, to: overlays.appendingPathComponent(r.file), quality: 0.7)
        }
    }
    print("kind                    matched (IoU≥0.5)   mean IoU   only on the copy")
    for (k, st) in stats.sorted(by: { $0.key < $1.key }) {
        print(String(format: "%-22@ %5d / %-5d %8.2f %10d", k as NSString, st.matched, st.total, st.total > 0 ? st.iou / Double(st.total) : 0, st.extra))
    }
    print("\nLowest mean IoU:")
    for (f, m) in worst.sorted(by: { $0.1 < $1.1 }).prefix(15) { print(String(format: "  %.2f  %@", m, f as NSString)) }
    if fixtures != nil {
        print("Sensitive fields hidden: \(hidden)/\(toHide)   Fields kept visible: \(kept)/\(toKeep)")
        exit(hidden == toHide && kept == toKeep ? 0 : 1)
    }

default:
    print(usage)
    exit(2)
}
