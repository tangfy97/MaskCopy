import CoreGraphics
import Foundation
import CoreML
import Vision

/// Reads one page of a document and suggests what to hide. Everything runs on the device.
public struct Analyzer {
    public init() {}

    /// Finds the document in a photo, straightens it, and analyzes it.
    public func analyze(photo: CGImage) throws -> (DocumentImage, PageAnalysis) {
        let doc = Rectifier.straighten(photo)
        return (doc, try analyze(doc.image, fillsFrame: doc.fillsFrame, expectedLines: doc.quickLines))
    }

    /// Analyzes an upright image. `fillsFrame` says the image is the document edge to edge,
    /// which lets layout rules use the image's edges.
    public func analyze(_ image: CGImage, fillsFrame: Bool = false, expectedLines: Int = 0) throws -> PageAnalysis {
        let aspect = CGFloat(image.width) / CGFloat(max(image.height, 1))
        let (lines, faces, barcodes) = try recognize(image, expectedLines: expectedLines)
        var page = Page(lines: lines, aspect: aspect)
        page.fillsFrame = fillsFrame
        page.luma = Luma(image)

        // 1. Machine-readable zone: the most reliable thing on a passport or ID card.
        let (mrz, mrzLines) = MRZReader.find(in: lines)
        page.mrzLines = mrzLines
        if !mrzLines.isEmpty {
            // Each line fitted to its ink; the zone runs from the first line's top to the last line's
            // bottom and from the leftmost to the rightmost character. Nothing beyond the characters.
            let fitted = mrzLines.map { page.fitted($0.quad) }
            var zone = Quad(tl: fitted.first!.tl, tr: fitted.first!.tr, br: fitted.last!.br, bl: fitted.last!.bl)
            let left = fitted.map { min($0.tl.x, $0.bl.x) }.min()!, right = fitted.map { max($0.tr.x, $0.br.x) }.max()!
            zone = zone.extendedAcross(to: left, right)
            page.add(.machineReadableZone, zone, padding: 0, note: mrz.map { "MRZ \($0.format.rawValue)" } ?? "MRZ-like lines", fit: false)
        }

        // 2. Which document, from which country.
        let folded = lines.map { $0.text.foldedUpper }
        let country = mrz.flatMap { Countries.country(mrzCode: $0.issuingState) }
            ?? Self.keywordCountry(folded)
            ?? Self.strongPatternCountry(page)
        let numbered = Self.isNumberedLayout(folded)
        var kind = mrz?.documentKind ?? Self.keywordKind(folded) ?? (numbered ? .drivingLicence : .unknown)
        if kind == .unknown, numbered { kind = .drivingLicence }
        page.country = country?.code
        page.kind = kind

        // 3. Personal and document numbers anywhere on the page.
        page.findNumbers()

        // 4. Values the MRZ tells us about, wherever else they are printed.
        if let mrz {
            if mrz.documentNumber.count >= 5 { page.findLiteral(mrz.documentNumber, kind: .documentNumber, note: "document number from MRZ") }
            if let p = mrz.personalNumber { page.findLiteral(p, kind: .personalNumber, note: "personal number from MRZ") }
        }

        // 5. Labelled fields and numbered licence fields.
        page.findLabelledValues()
        page.findFieldCodes(numbered: numbered)
        if kind != .passport { page.findStandaloneNumbers() }
        if kind == .idCard || kind == .residencePermit || mrz?.format == .td1 || country.map({ $0.region == .europe }) == true && kind != .passport {
            page.findCardAccessNumber()
        }
        if let code = country?.code, ["US", "CA", "AU", "NZ", "GB", "IE", "SG", "MY"].contains(code) || country == nil {
            page.findStreetAddresses()
        }

        // 6. Photos and barcodes.
        for face in faces { page.addPhoto(around: face) }
        if faces.isEmpty { page.addLayoutPhoto() }
        // Where the portrait has a visible edge, the mask is that edge exactly.
        for i in page.findings.indices where page.findings[i].kind == .photo {
            if let edge = portraitEdge(near: page.findings[i].shape, face: faces.first { page.findings[i].rect.contains(CGPoint(x: $0.midX, y: $0.midY)) }, in: image) {
                page.findings[i] = Finding(kind: .photo, quad: edge, note: page.findings[i].note + ", portrait edge")
            }
        }
        for (quad, _) in barcodes { page.add(.barcode, quad, padding: 0.02, note: "barcode", fit: false) }
        // The PDF417 on the back of North American licences and ID cards (AAMVA).
        if kind == .unknown, barcodes.contains(where: { $0.1?.contains("ANSI ") == true }) { kind = .drivingLicence }

        return PageAnalysis(kind: kind, country: country, mrz: mrz, findings: page.merged(), lines: lines.map { String(format: "%@  [%.3f %.3f %.3f %.3f]", $0.text, $0.box.minX, $0.box.minY, $0.box.width, $0.box.height) })
    }

    // MARK: Vision

    private func recognize(_ image: CGImage, expectedLines: Int = 0) throws -> ([TextLine], [CGRect], [(Quad, String?)]) {
        func textRequest() -> VNRecognizeTextRequest {
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.usesLanguageCorrection = false
            text.automaticallyDetectsLanguage = true
            return text
        }
        var text = textRequest()
        let faces = VNDetectFaceRectanglesRequest()
        let barcodes = VNDetectBarcodesRequest()
        // Text is required; faces and barcodes are best effort, so one failing never loses the others.
        try perform(text, on: image)
        try? perform(faces, on: image)
        try? perform(barcodes, on: image)
        var lines = Self.lines(from: text.results ?? [])
        // The full read occasionally comes back with lines missing (seen under load). If it found clearly
        // fewer than the quick read did, read again and keep the more complete result.
        for _ in 0..<2 where expectedLines > 4 && Double(lines.count) < Double(expectedLines) * 0.8 {
            let again = textRequest()
            try perform(again, on: image)
            let more = Self.lines(from: again.results ?? [])
            if more.count > lines.count { lines = more; text = again }
        }
        if Page.debug { print("  · recognize \(image.width)x\(image.height): \(text.results?.count ?? -1) observations, \(lines.count) lines") }

        // A second pass in Chinese, Japanese or Korean when the page has such text.
        let all = lines.map(\.text).joined()
        if all.containsCJK {
            let cjk = VNRecognizeTextRequest()
            cjk.recognitionLevel = .accurate
            cjk.usesLanguageCorrection = false
            cjk.recognitionLanguages = all.containsHangul ? ["ko-KR", "en-US"] : all.containsKana ? ["ja-JP", "en-US"] : ["zh-Hans", "zh-Hant", "en-US"]
            try perform(cjk, on: image)
            let second = Self.lines(from: cjk.results ?? []).filter { $0.text.containsCJK }
            lines = second + lines.filter { a in !second.contains { iou(a.box, $0.box) > 0.3 } }
        }

        let faceRects = (faces.results ?? []).map(\.boundingBox.flippedVertically)
        let codeRects = (barcodes.results ?? []).map { (Rectifier.quad($0), $0.payloadStringValue) }
        return (lines, faceRects, codeRects)
    }

    private func perform(_ request: VNRequest, on image: CGImage) throws {
        try VisionRunner.perform(request, on: image)
    }

    private static func lines(from observations: [VNRecognizedTextObservation]) -> [TextLine] {
        observations.compactMap { o in
            guard let c = o.topCandidates(1).first else { return nil }
            return TextLine(text: c.string, quad: Rectifier.quad(o), candidate: c)
        }
    }

    // MARK: Portrait edge

    /// The portrait's own rectangle near an estimate: an upright frame, about as tall as passport
    /// photos are for their width, that holds the face (if one was found) and is close to the estimate's size.
    private func portraitEdge(near estimate: Quad, face: CGRect?, in image: CGImage) -> Quad? {
        let est = estimate.boundingRect
        let roi = est.insetBy(dx: -est.width * 0.35, dy: -est.height * 0.25).clampedToUnit()
        guard roi.width > 0.02, roi.height > 0.02 else { return nil }
        let r = VNDetectRectanglesRequest()
        r.regionOfInterest = CGRect(x: roi.minX, y: 1 - roi.maxY, width: roi.width, height: roi.height)
        r.minimumAspectRatio = 0.55
        r.maximumAspectRatio = 0.95
        r.minimumSize = 0.35
        r.quadratureTolerance = 12
        r.minimumConfidence = 0.4
        r.maximumObservations = 6
        guard (try? perform(r, on: image)) != nil else { return nil }
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        let estArea = est.width * est.height
        // Read each result both as relative to the region of interest and to the whole image;
        // only the reading that lands on the portrait passes the checks below.
        let candidates = (r.results ?? []).flatMap { o -> [Quad] in
            let q = Rectifier.quad(o)
            return [q.mapped { CGPoint(x: roi.minX + $0.x * roi.width, y: roi.minY + $0.y * roi.height) }, q]
        }.filter { q in
            let b = q.boundingRect
            let ratio = (b.width * aspect) / b.height
            guard (0.6...0.95).contains(ratio) else { return false }
            let area = b.width * b.height
            guard area > estArea * 0.45, area < estArea * 2.2 else { return false }
            if let face { return q.contains(CGPoint(x: face.midX, y: face.midY)) && b.contains(face.insetBy(dx: face.width * 0.15, dy: face.height * 0.15)) }
            return b.intersectionArea(est) > 0.5 * area
        }
        return candidates.min { abs($0.boundingRect.width * $0.boundingRect.height - estArea) < abs($1.boundingRect.width * $1.boundingRect.height - estArea) }
    }

    // MARK: Classification

    static func keywordCountry(_ folded: [String]) -> Country? {
        let text = folded.joined(separator: "\n")
        for (word, code) in Countries.keywords where !tokenRanges(of: word, in: text).isEmpty {
            return Countries.byCode[code]
        }
        return nil
    }

    static func keywordKind(_ folded: [String]) -> DocumentKind? {
        let text = folded.joined(separator: "\n")
        // Long names are matched anywhere ("IDENTITAÙ" still says IDENTITA); short ones as whole words.
        for (word, kind) in Countries.documentKeywords where word.count >= 8 ? text.contains(word) : !tokenRanges(of: word, in: text).isEmpty {
            return kind
        }
        return nil
    }

    static func strongPatternCountry(_ page: Page) -> Country? {
        for line in page.lines {
            let variants = [MappedText(line.text, dropSpaces: false, latinize: true), MappedText(line.text, dropSpaces: true, latinize: true)]
            for p in NumberPattern.all where p.strength == .strong && p.countries.count == 1 {
                for v in variants where v.matches(p.regex).contains(where: { p.validate($0.1) }) {
                    return Countries.byCode[p.countries.first!]
                }
            }
        }
        return nil
    }

    static func fieldCode(of folded: String) -> (code: String, rest: Substring)? {
        // "4d. 123", "4d 123", "5.", "8 MAIN ST"
        var i = folded.startIndex
        while i < folded.endIndex, folded[i].isNumber { i = folded.index(after: i) }
        guard i > folded.startIndex, folded.distance(from: folded.startIndex, to: i) <= 2 else { return nil }
        if i < folded.endIndex, ("A"..."D").contains(folded[i]) {
            let next = folded.index(after: i)
            if next == folded.endIndex || !folded[next].isLetter { i = next }
        }
        let code = String(folded[..<i])
        guard i == folded.endIndex || folded[i] == "." || folded[i] == " " || folded[i] == ":" else { return nil }
        return (code, folded[i...].drop { $0 == "." || $0 == " " || $0 == ":" })
    }

    static func isNumberedLayout(_ folded: [String]) -> Bool {
        let codes = Set(folded.compactMap { fieldCode(of: $0)?.code }.filter { Labels.layoutCodes.contains($0) })
        return codes.count >= 4
    }
}

func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let i = a.intersectionArea(b)
    let u = a.area + b.area - i
    return u > 0 ? i / u : 0
}

/// Working state while one page is analyzed.
struct Page {
    let lines: [TextLine]
    let aspect: CGFloat // width / height
    var mrzLines: [TextLine] = []
    var country: String?
    var kind: DocumentKind = .unknown
    var fillsFrame = false
    var luma: Luma?
    var findings: [Finding] = []
    /// How exactly each finding's shape was measured: 2 cut at the gap before or after it,
    /// 1 fitted to its ink, 0 an estimate. When two overlap, the more exact one is kept.
    var exactness: [UUID: Int] = [:]

    init(lines: [TextLine], aspect: CGFloat) {
        self.lines = lines
        self.aspect = aspect
    }

    private var textLines: [TextLine] {
        lines.filter { l in !mrzLines.contains { $0.box == l.box } }
    }

    /// For part of a line that runs to one end of it: how many words it has, and which end.
    /// The ink fit then drops anything (a label) that Vision's box took in from the other side.
    func words(_ range: Range<String.Index>, in line: TextLine) -> (count: Int, fromEnd: Bool)? {
        let n = line.text[range].split(whereSeparator: \.isWhitespace).count
        let atStart = range.lowerBound == line.text.startIndex, atEnd = range.upperBound == line.text.endIndex
        if atEnd && !atStart { return (n, true) }
        if atStart && !atEnd { return (n, false) }
        return nil
    }

    static let debug = ProcessInfo.processInfo.environment["MASKE_DEBUG"] != nil
    func log(_ s: @autoclosure () -> String) { if Page.debug { print("  · " + s()) } }

    /// Part of a line (a value after its label, a number inside a line), fitted to exactly its ink.
    mutating func addPart(_ kind: FindingKind, of line: TextLine, _ range: Range<String.Index>, note: String) {
        let w = words(range, in: line)
        if let w, let luma {
            // Where the part starts (or ends) as a share of the line, from how wide its characters are.
            let total = line.text.reduce(0) { $0 + InkFit.advance($1) }
            let before = line.text[..<range.lowerBound].reduce(0) { $0 + InkFit.advance($1) }
            let inside = line.text[range].reduce(0) { $0 + InkFit.advance($1) }
            if total > 0, let part = InkFit.fitPart(of: line.quad, in: luma, boundary: w.fromEnd ? before / total : (before + inside) / total, keepEnd: w.fromEnd) {
                // Only if its width is about what its characters need.
                let expected = inside / total * line.box.width
                let got = part.boundingRect.width
                log(String(format: "part %@ “%@”: width %.3f expected %.3f h %.3f", note, String(line.text[range]), got, expected, part.boundingRect.height))
                if abs(got - expected) <= 0.2 * expected + 0.5 * line.box.height / aspect {
                    let f = Finding(kind: kind, rect: part.boundingRect.clampedToUnit(), quad: part, note: note)
                    findings.append(f)
                    exactness[f.id] = 2
                    return
                }
            }
        }
        add(kind, line.quad(for: range), note: note, words: w)
    }

    /// Text's shape fitted to its ink (see `InkFit`); when the pixels don't allow that, Vision's
    /// box grown a little so nothing is left showing.
    func fitted(_ quad: Quad) -> Quad {
        if let luma, let q = InkFit.fit(quad, in: luma) { return q }
        return quad.expanded(by: 0.15, aspect: aspect)
    }

    /// Adds a shape. Text is fitted to its ink; other shapes are grown by `padding` × their height.
    mutating func add(_ kind: FindingKind, _ quad: Quad, padding: CGFloat = 0.15, note: String, fit: Bool = true,
                      words: (count: Int, fromEnd: Bool)? = nil) {
        guard quad.area() > 0 else { return }
        let q: Quad
        var exact = 0
        if fit, let luma, let tight = InkFit.fit(quad, in: luma, words: words) {
            q = tight
            exact = 1
        } else {
            q = padding > 0 ? quad.expanded(by: padding, aspect: aspect) : quad
        }
        let f = Finding(kind: kind, rect: q.boundingRect.clampedToUnit(), quad: q, note: note)
        findings.append(f)
        exactness[f.id] = exact
        log(String(format: "add %@ exact %d: x %.3f y %.3f w %.3f h %.3f (from h %.3f)", note, exact, f.rect.minX, f.rect.minY, f.rect.width, f.rect.height, quad.boundingRect.height))
    }

    // MARK: Numbers

    mutating func findNumbers() {
        let patterns = NumberPattern.all.filter { $0.applies(to: country) }
        for line in textLines {
            let variants = [
                MappedText(line.text, dropSpaces: false, latinize: true),
                MappedText(line.text, dropSpaces: true, latinize: true),
                MappedText(line.text, dropSpaces: true, digitize: true),
            ]
            var taken: [Range<String.Index>] = []
            for p in patterns {
                for (i, v) in variants.enumerated() where i < 2 || p.numeric {
                    for (range, value) in v.matches(p.regex) where p.validate(value) {
                        if taken.contains(where: { $0.overlaps(range) && $0 == range }) { continue }
                        taken.append(range)
                        addPart(p.kind, of: line, range, note: p.name)
                    }
                }
            }
        }
    }

    mutating func findLiteral(_ value: String, kind: FindingKind, note: String) {
        let needle = value.foldedUpper
        for line in textLines {
            let v = MappedText(line.text, dropSpaces: true)
            var start = v.value.startIndex
            while let r = v.value.range(of: needle, range: start..<v.value.endIndex) {
                if let o = v.originalRange(r) { addPart(kind, of: line, o, note: note) }
                start = r.upperBound
            }
        }
    }

    // MARK: Labels

    mutating func findLabelledValues() {
        let lines = textLines
        for (index, line) in lines.enumerated() {
            let v = MappedText(line.text, dropSpaces: false)
            for (kind, labels) in Labels.rules {
                for label in labels {
                    for r in tokenRanges(of: label, in: v.value) {
                        guard let o = v.originalRange(r) else { continue }
                        addValue(after: o, in: line, index: index, among: lines, kind: kind, note: "label \(label)")
                    }
                }
            }
        }
    }

    /// The value of a label: the rest of its line, or the text to its right, or the line below.
    mutating func addValue(after label: Range<String.Index>, in line: TextLine, index: Int, among lines: [TextLine], kind: FindingKind, note: String) {
        let rest = line.text[label.upperBound...]
        let skip = CharacterSet(charactersIn: " .:/#№：-").union(.whitespaces)
        if let start = rest.unicodeScalars.firstIndex(where: { !skip.contains($0) }) {
            let valueRange = start..<line.text.endIndex
            let value = line.text[valueRange]
            // Stop at a second label on the same line ("Date of birth   Personal No.").
            if looksLikeValue(String(value), kind) && !Labels.rules.contains(where: { $0.1.contains { String(value).foldedUpper.hasPrefix($0) } }) {
                let q = line.quad(for: valueRange)
                addPart(kind, of: line, valueRange, note: note)
                if kind == .address { addContinuation(below: q.boundingRect, among: lines, note: note) }
                return
            }
        }
        let labelBox = line.box(for: label)
        // To the right on the same line.
        if let right = lines.filter({ abs($0.box.midY - labelBox.midY) < labelBox.height * 0.6 && $0.box.minX >= labelBox.maxX - 0.005 && $0.box.minX - labelBox.maxX < 0.3 && looksLikeValue($0.text, kind) })
            .min(by: { $0.box.minX < $1.box.minX }) {
            add(kind, right.quad, note: note)
            if kind == .address { addContinuation(below: right.box, among: lines, note: note) }
            return
        }
        // Below, starting near the label's left edge.
        if let below = lineBelow(labelBox, among: lines, maxGap: 1.8), looksLikeValue(below.text, kind) {
            add(kind, below.quad, note: note)
            if kind == .address { addContinuation(below: below.box, among: lines, note: note) }
        }
    }

    /// Numbers have digits; an address may not. This keeps a neighbouring label from being taken for the value.
    func looksLikeValue(_ s: String, _ kind: FindingKind) -> Bool {
        let alnum = s.filter { $0.isNumber || $0.isLetter }.count
        if kind == .address { return alnum >= 2 }
        return s.filter(\.isNumber).count >= 2
    }

    func lineBelow(_ box: CGRect, among lines: [TextLine], maxGap: CGFloat) -> TextLine? {
        lines.filter { l in
            l.box.minY > box.midY && l.box.minY - box.maxY < box.height * maxGap
                && l.box.minX < box.minX + max(box.width, 0.12) && l.box.maxX > box.minX - 0.02
        }.min { $0.box.minY < $1.box.minY }
    }

    /// Addresses run over two or three lines.
    mutating func addContinuation(below box: CGRect, among lines: [TextLine], note: String) {
        var current = box
        for _ in 0..<2 {
            guard let next = lineBelow(current, among: lines, maxGap: 1.7) else { return }
            let folded = next.text.foldedUpper
            if Analyzer.fieldCode(of: folded) != nil || Labels.rules.contains(where: { $0.1.contains { folded.hasPrefix($0) } }) { return }
            add(.address, next.quad, note: note + " (continued)")
            current = next.box
        }
    }

    // MARK: Numbered licence fields

    mutating func findFieldCodes(numbered: Bool) {
        let lines = textLines
        for (index, line) in lines.enumerated() {
            let folded = line.text.foldedUpper
            guard let (code, _) = Analyzer.fieldCode(of: folded), var kind = Labels.fieldCodes[code] else { continue }
            if code != "4D" && !numbered { continue }
            if code == "4D", folded.contains("DLN") || country == "US" || country == "CA" { kind = .documentNumber }
            // The code itself in the original string: as many characters as the folded code.
            let codeEnd = line.text.index(line.text.startIndex, offsetBy: min(code.count, line.text.count))
            addValue(after: line.text.startIndex..<codeEnd, in: line, index: index, among: lines, kind: kind, note: "field \(code)")
        }
        // AAMVA puts "DL" before the licence number on many US cards.
        for (index, line) in lines.enumerated() where country == "US" || country == "CA" {
            let folded = line.text.foldedUpper
            if folded.hasPrefix("DL "), let r = line.text.range(of: "DL", options: .caseInsensitive) {
                addValue(after: r, in: line, index: index, among: lines, kind: .documentNumber, note: "AAMVA DL")
            }
        }
    }

    // MARK: Unlabelled document numbers

    /// A line that is a single code mixing letters and digits ("L01X00T47"), or seven or more digits:
    /// on cards this is nearly always the document or licence number printed without a label.
    mutating func findStandaloneNumbers() {
        for line in textLines {
            let t = String(MappedText(line.text, dropSpaces: true, latinize: true).value)
            guard (6...14).contains(t.count), t.allSatisfy({ ("A"..."Z").contains($0) || $0.isASCII && $0.isNumber }) else { continue }
            let folded = line.text.foldedUpper
            if Self.date.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)) != nil { continue }
            let digits = t.filter(\.isNumber).count, letters = t.count - digits
            if letters == 0 && digits >= 7 || letters >= 1 && digits >= 3 && letters <= digits + 2 {
                add(.documentNumber, line.quad, note: "unlabelled number")
            }
        }
    }

    // MARK: Card access number

    /// The six-digit CAN printed on the front of European ID cards opens the chip.
    mutating func findCardAccessNumber() {
        for line in textLines {
            let t = line.text.filter { !$0.isWhitespace }
            if t.count == 6, t.allSatisfy(\.isNumber) { add(.cardAccessNumber, line.quad, note: "6-digit CAN") }
        }
    }

    // MARK: Street addresses without a label

    static let date = try! NSRegularExpression(pattern:
        #"^\s*(?:\d{1,2}[ ./-]*(?:[A-Z]{3,5}|\d{1,2})[ ./-]*\d{2,4}|\d{4}[ ./-]*\d{1,2}[ ./-]*\d{1,2})\s*$"#)

    static let street = try! NSRegularExpression(pattern:
        #"^(?:BLK |BLOCK |NO\.? ?|LOT |UNIT )?\d{1,5}[A-Z]?[ ,/-]+(?:[A-Z0-9'.-]+ )*(?:ST|STREET|RD|ROAD|AVE|AVENUE|DR|DRIVE|LN|LANE|BLVD|WAY|CT|COURT|PL|PLACE|CRES|CRESCENT|HWY|TCE|TERRACE|PDE|PARADE|CL|CLOSE|SQ|GROVE|GR)\b|\b(?:JALAN|JLN|LORONG|TAMAN|PERSIARAN)\b"#)
    static let postcodeLine = try! NSRegularExpression(pattern:
        #"^\d{4,6} [A-Z]{3,}|\b(?:[A-Z]{2,3} \d{4,5}(?:-\d{4})?|\d{4,6})$|\b[A-Z]\d[A-Z] ?\d[A-Z]\d$|\b[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$"#)

    mutating func findStreetAddresses() {
        let lines = textLines
        for line in lines {
            let t = line.text.foldedUpper
            guard Self.street.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil else { continue }
            add(.address, line.quad, note: "street address")
            if let next = lineBelow(line.box, among: lines, maxGap: 1.7) {
                let n = next.text.foldedUpper
                if Self.postcodeLine.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)) != nil {
                    add(.address, next.quad, note: "street address (postcode)")
                }
            }
        }
    }

    // MARK: Photos

    /// A face found by Vision, grown to the portrait around it: ICAO portraits are about twice
    /// the face's height, with the hair above and the shoulders below.
    mutating func addPhoto(around face: CGRect) {
        let h = face.height * 2.05
        let w = min(face.width * 1.75, h / aspect * 0.95)
        let r = CGRect(x: face.midX - w / 2, y: face.minY - face.height * 0.55, width: w, height: h)
        findings.append(Finding(kind: .photo, rect: r.clampedToUnit(), note: "face"))
    }

    /// Where the portrait sits by standard, for when no face is found (worn or glossy photos).
    mutating func addLayoutPhoto() {
        switch kind {
        case .passport:
            // ICAO 9303 TD3: the portrait (zone V) is about 6–41 mm from the left and ends a few
            // millimetres above the MRZ. Millimetres come from the MRZ's own character pitch (2.54 mm),
            // and directions from its tilt, so this works without knowing where the page edges are.
            guard let line = mrzLines.first, line.text.count >= 30 else { return }
            let a = CGPoint(x: line.quad.tl.x * aspect, y: line.quad.tl.y), b = CGPoint(x: line.quad.tr.x * aspect, y: line.quad.tr.y)
            let across = normalize(minus(b, a)), down = CGPoint(x: -across.y, y: across.x)
            let mm = dist(a, b) / (CGFloat(MRZReader.normalize(line.text).count) * 2.54)
            func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                let p = plus(plus(a, scale(across, x * mm)), scale(down, y * mm))
                return CGPoint(x: p.x / aspect, y: p.y)
            }
            let q = Quad(tl: at(-4, -58), tr: at(36, -58), br: at(36, -2), bl: at(-4, -2))
            findings.append(Finding(kind: .photo, rect: q.boundingRect.clampedToUnit(), quad: q, note: "ICAO portrait zone"))
        case .drivingLicence where fillsFrame && Analyzer.isNumberedLayout(lines.map { $0.text.foldedUpper }):
            // Field 6 sits at the left of the front of EU and ISO 18013 cards.
            let textMinX = textLines.map(\.box.minX).filter { $0 > 0.2 }.min() ?? 0.32
            findings.append(Finding(kind: .photo, rect: CGRect(x: 0.03, y: 0.2, width: max(0.2, textMinX - 0.05), height: 0.62), note: "ISO 18013 portrait zone"))
        default:
            break
        }
    }

    // MARK: Merge

    /// One box per thing. Text boxes found by several rules are reduced to the largest; photo
    /// and barcode boxes that overlap are joined.
    func merged() -> [Finding] {
        var out: [Finding] = []
        var rank: [UUID: Int] = [:]
        for f in findings {
            let fr = exactness[f.id] ?? 0
            if let i = out.firstIndex(where: { $0.kind == f.kind && $0.rect.intersectionArea(f.rect) > 0.6 * min($0.rect.area, f.rect.area) }) {
                let or = rank[out[i].id] ?? 0
                if out[i].quad == nil && f.quad == nil {
                    out[i].rect = out[i].rect.union(f.rect)
                } else if fr > or || (fr == or && f.shape.area(aspect: aspect) > out[i].shape.area(aspect: aspect)) {
                    // The more exactly measured shape wins; between equals, the larger (nothing left showing).
                    let note = out[i].note
                    out[i] = Finding(id: out[i].id, kind: f.kind, rect: f.rect, quad: f.quad, note: note)
                    rank[out[i].id] = fr
                }
                if !out[i].note.contains(f.note) { out[i].note += ", " + f.note }
            } else {
                out.append(f)
                rank[f.id] = fr
            }
        }
        return out
    }
}
