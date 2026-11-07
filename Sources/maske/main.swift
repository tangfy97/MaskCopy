import CoreGraphics
import Foundation
import MaskeCore
import UniformTypeIdentifiers

let usage = """
maske fixtures <dir>      make the synthetic documents and their expected answers
maske eval <dir>          check the engine against them; writes masked copies to <dir>/out
maske analyze <image>     print what the engine finds on one image
"""

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
    let a = try Analyzer().analyze(image)
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

    /// Share of `box` covered by the boxes that are on, sampled on a grid.
    func coverage(_ box: CGRect, _ findings: [Finding]) -> Double {
        let on = findings.filter(\.isOn).map(\.rect)
        var hit = 0, total = 0
        for i in 0..<24 {
            for j in 0..<6 {
                let p = CGPoint(x: box.minX + box.width * (CGFloat(i) + 0.5) / 24, y: box.minY + box.height * (CGFloat(j) + 0.5) / 6)
                total += 1
                if on.contains(where: { $0.contains(p) }) { hit += 1 }
            }
        }
        return Double(hit) / Double(total)
    }

    var hidden = 0, toHide = 0, kept = 0, toKeep = 0, docsOK = 0, kindsOK = 0, countriesOK = 0
    var problems: [String] = []
    for e in expected {
        guard let image = Fixtures.load(url.appendingPathComponent(e.name + ".png")) else { continue }
        let a = try Analyzer().analyze(image)
        var ok = true
        for b in e.hide {
            toHide += 1
            if coverage(b.rect, a.findings) >= 0.9 { hidden += 1 } else { ok = false; problems.append("\(e.name): not hidden \(b.kind) “\(b.text)”") }
        }
        for b in e.keep {
            toKeep += 1
            if coverage(b.rect, a.findings) <= 0.1 { kept += 1 } else { ok = false; problems.append("\(e.name): hidden by mistake “\(b.text)”") }
        }
        if a.kind.rawValue == e.kind { kindsOK += 1 } else { problems.append("\(e.name): kind \(a.kind.rawValue), expected \(e.kind)") }
        if a.country?.code == e.country { countriesOK += 1 } else { problems.append("\(e.name): country \(a.country?.code ?? "?"), expected \(e.country)") }
        if ok { docsOK += 1 }
        if let copy = Renderer.render(pages: [(image, a.findings)], watermark: Watermark(recipient: "Test", purpose: e.name)),
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
    print("Sensitive fields hidden: \(hidden)/\(toHide)   Fields kept visible: \(kept)/\(toKeep)")
    print("Document kind right: \(kindsOK)/\(expected.count)   Country right: \(countriesOK)/\(expected.count)")
    exit(problems.contains { $0.contains("not hidden") } ? 1 : 0)

default:
    print(usage)
    exit(2)
}
