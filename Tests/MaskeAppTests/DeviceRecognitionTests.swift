import XCTest
import ImageIO
@testable import Maske

/// Generated samples and official specimens in the test bundle, never the shipping app or Photos library.
final class DeviceRecognitionTests: XCTestCase {
    private struct Expected: Decodable {
        struct Region: Decodable { let kind: String; let rect: CGRect }
        let name: String
        let file: String?
        let country: String
        let kind: String
        let hide: [Region]
        let keep: [Region]
    }

    func testNorwayNetherlandsChinaPipeline() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Full Vision latency/accuracy check requires physical iPhone hardware")
        #else
        try run(manifest: "expected", names: ["dl-nld", "id-nor-front", "id-chn-front", "passport-chn"], iterations: 3)
        #endif
    }

    func testAnnotatedOfficialSpecimens() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Official specimen check requires physical iPhone hardware")
        #else
        try run(manifest: "specimen-focus", names: nil, iterations: 2)
        #endif
    }

    private func run(manifest: String, names: [String]?, iterations: Int) throws {
        let bundle = Bundle(for: Self.self)
        guard let labels = bundle.url(forResource: manifest, withExtension: "json") else {
            throw XCTSkip("Generate/download the documented fixtures before building device tests")
        }
        let expected = try JSONDecoder().decode([Expected].self, from: Data(contentsOf: labels))
        let selected = names ?? expected.map(\.name)
        var timings: [[String: Any]] = []
        for iteration in 0..<iterations {
            for name in selected {
                try autoreleasepool {
                    let label = try XCTUnwrap(expected.first { $0.name == name })
                    let file = URL(fileURLWithPath: label.file ?? name + ".png")
                    let url = try XCTUnwrap(bundle.url(forResource: file.deletingPathExtension().lastPathComponent, withExtension: file.pathExtension))
                    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
                    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0,
                        [kCGImageSourceShouldCacheImmediately: true] as CFDictionary))
                    let clock = ContinuousClock()
                    let start = clock.now
                    let (document, analysis) = try Analyzer().analyze(photo: image)
                    let elapsed = start.duration(to: clock.now)
                    let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                    let findings = analysis.findings.map { Finding(kind: $0.kind, quad: document.toSource.apply($0.shape)) }
                    let hidden = label.hide.map { coverage($0.rect, findings: findings) }
                    let kept = label.keep.map { coverage($0.rect, findings: findings) }
                    timings.append(["fixture": name, "iteration": iteration, "seconds": seconds,
                        "sensitiveCoverage": hidden, "keptCoverage": kept,
                        "kind": analysis.kind.rawValue, "country": analysis.country?.code ?? "unknown"])
                    XCTAssertEqual(analysis.kind.rawValue, label.kind, name)
                    XCTAssertEqual(analysis.country?.code, label.country, name)
                    for (index, coverage) in hidden.enumerated() {
                        XCTAssertGreaterThanOrEqual(coverage, 0.98, "\(name) \(label.hide[index].kind)")
                    }
                    for coverage in kept { XCTAssertLessThanOrEqual(coverage, 0.10, name) }
                    if iteration == 0, let copy = Renderer.render(pages: [(document.image, analysis.findings)],
                        watermark: Watermark(recipient: "Device validation")), let data = Renderer.jpegData(copy) {
                        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.jpeg")
                        attachment.name = name + " device copy"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: timings, options: [.prettyPrinted, .sortedKeys]),
                                      uniformTypeIdentifier: "public.json")
        attachment.name = manifest + " device recognition timings and coverage"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func coverage(_ rect: CGRect, findings: [Finding]) -> Double {
        var hits = 0
        for x in 0..<48 {
            for y in 0..<12 {
                let point = CGPoint(x: rect.minX + rect.width * (CGFloat(x) + 0.5) / 48,
                                    y: rect.minY + rect.height * (CGFloat(y) + 0.5) / 12)
                if findings.contains(where: { $0.isOn && $0.contains(point) }) { hits += 1 }
            }
        }
        return Double(hits) / (48 * 12)
    }
}
