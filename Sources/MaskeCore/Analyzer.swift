import CoreGraphics
import Foundation
import CoreML
import Vision

/// Reads one page of a document and suggests what to hide. Everything runs on the device.
public struct Analyzer {
    public init() {}

    public func analyze(_ image: CGImage) throws -> PageAnalysis {
        let aspect = CGFloat(image.width) / CGFloat(max(image.height, 1))
        let (lines, faces, barcodes) = try recognize(image)
        var page = Page(lines: lines, aspect: aspect)

        // 1. Machine-readable zone: the most reliable thing on a passport or ID card.
        let (mrz, mrzLines) = MRZReader.find(in: lines)
        page.mrzLines = mrzLines
        if !mrzLines.isEmpty {
            var union = mrzLines.map(\.box).reduce(mrzLines[0].box) { $0.union($1) }
            // The zone spans the whole width of the document, whatever the text's length.
            union = CGRect(x: min(union.minX, 0.02), y: union.minY, width: max(union.maxX, 0.98) - min(union.minX, 0.02), height: union.height)
            page.add(.machineReadableZone, union, padding: 0.5, note: mrz.map { "MRZ \($0.format.rawValue)" } ?? "MRZ-like lines")
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
        for (box, _) in barcodes { page.add(.barcode, box, padding: 0, note: "barcode") }
        // The PDF417 on the back of North American licences and ID cards (AAMVA).
        if kind == .unknown, barcodes.contains(where: { $0.1?.contains("ANSI ") == true }) { kind = .drivingLicence }

        return PageAnalysis(kind: kind, country: country, mrz: mrz, findings: page.merged(), lines: lines.map { String(format: "%@  [%.3f %.3f %.3f %.3f]", $0.text, $0.box.minX, $0.box.minY, $0.box.width, $0.box.height) })
    }

    // MARK: Vision

    private func recognize(_ image: CGImage) throws -> ([TextLine], [CGRect], [(CGRect, String?)]) {
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = false
        text.automaticallyDetectsLanguage = true
        let faces = VNDetectFaceRectanglesRequest()
        let barcodes = VNDetectBarcodesRequest()
        // Text is required; faces and barcodes are best effort, so one failing never loses the others.
        try perform(text, on: image)
        try? perform(faces, on: image)
        try? perform(barcodes, on: image)
        var lines = Self.lines(from: text.results ?? [])

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
        let codeRects = (barcodes.results ?? []).map { ($0.boundingBox.flippedVertically, $0.payloadStringValue) }
        return (lines, faceRects, codeRects)
    }

    private func perform(_ request: VNRequest, on image: CGImage) throws {
        #if targetEnvironment(simulator)
        // The simulator has no Neural Engine; Vision's models run there only on the CPU.
        if let devices = try? request.supportedComputeStageDevices {
            for (stage, list) in devices {
                if let cpu = list.first(where: { if case .cpu = $0 { return true } else { return false } }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        }
        #endif
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    }

    private static func lines(from observations: [VNRecognizedTextObservation]) -> [TextLine] {
        observations.compactMap { o in
            guard let c = o.topCandidates(1).first else { return nil }
            return TextLine(text: c.string, box: o.boundingBox.flippedVertically, candidate: c)
        }
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
        for (word, kind) in Countries.documentKeywords where !tokenRanges(of: word, in: text).isEmpty {
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
    var findings: [Finding] = []

    init(lines: [TextLine], aspect: CGFloat) {
        self.lines = lines
        self.aspect = aspect
    }

    private var textLines: [TextLine] {
        lines.filter { l in !mrzLines.contains { $0.box == l.box } }
    }

    /// Adds a box, grown by `padding` × its height on every side so the text is fully covered.
    mutating func add(_ kind: FindingKind, _ rect: CGRect, padding: CGFloat = 0.22, note: String) {
        guard rect.width > 0, rect.height > 0 else { return }
        let dy = rect.height * padding
        let dx = dy / aspect
        let r = rect.insetBy(dx: -dx, dy: -dy).clampedToUnit()
        findings.append(Finding(kind: kind, rect: r, note: note))
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
                        add(p.kind, line.box(for: range), note: p.name)
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
                if let o = v.originalRange(r) { add(kind, line.box(for: o), note: note) }
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
                let box = line.box(for: valueRange)
                add(kind, box, note: note)
                if kind == .address { addContinuation(below: box, among: lines, note: note) }
                return
            }
        }
        let labelBox = line.box(for: label)
        // To the right on the same line.
        if let right = lines.filter({ abs($0.box.midY - labelBox.midY) < labelBox.height * 0.6 && $0.box.minX >= labelBox.maxX - 0.005 && $0.box.minX - labelBox.maxX < 0.3 && looksLikeValue($0.text, kind) })
            .min(by: { $0.box.minX < $1.box.minX }) {
            add(kind, right.box, note: note)
            if kind == .address { addContinuation(below: right.box, among: lines, note: note) }
            return
        }
        // Below, starting near the label's left edge.
        if let below = lineBelow(labelBox, among: lines, maxGap: 1.8), looksLikeValue(below.text, kind) {
            add(kind, below.box, note: note)
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
            add(.address, next.box, note: note + " (continued)")
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
                add(.documentNumber, line.box, note: "unlabelled number")
            }
        }
    }

    // MARK: Card access number

    /// The six-digit CAN printed on the front of European ID cards opens the chip.
    mutating func findCardAccessNumber() {
        for line in textLines {
            let t = line.text.filter { !$0.isWhitespace }
            if t.count == 6, t.allSatisfy(\.isNumber) { add(.cardAccessNumber, line.box, note: "6-digit CAN") }
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
            add(.address, line.box, note: "street address")
            if let next = lineBelow(line.box, among: lines, maxGap: 1.7) {
                let n = next.text.foldedUpper
                if Self.postcodeLine.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)) != nil {
                    add(.address, next.box, note: "street address (postcode)")
                }
            }
        }
    }

    // MARK: Photos

    /// A face found by Vision, grown to the size of the portrait around it.
    mutating func addPhoto(around face: CGRect) {
        let w = face.width * 1.9, h = face.height * 2.3
        let r = CGRect(x: face.midX - w / 2, y: face.minY - face.height * 0.75, width: w, height: h)
        findings.append(Finding(kind: .photo, rect: r.clampedToUnit(), note: "face"))
    }

    /// Where the portrait sits by standard, for when no face is found (worn or glossy photos).
    mutating func addLayoutPhoto() {
        switch kind {
        case .passport where !mrzLines.isEmpty:
            let mrzTop = mrzLines.map(\.box.minY).min() ?? 0.8
            findings.append(Finding(kind: .photo, rect: CGRect(x: 0.03, y: max(0, mrzTop - 0.66), width: 0.29, height: 0.6), note: "ICAO portrait zone"))
        case .drivingLicence where Analyzer.isNumberedLayout(lines.map { $0.text.foldedUpper }):
            // Field 6 sits at the left of the front of EU and ISO 18013 cards.
            let textMinX = textLines.map(\.box.minX).filter { $0 > 0.2 }.min() ?? 0.32
            findings.append(Finding(kind: .photo, rect: CGRect(x: 0.03, y: 0.2, width: max(0.2, textMinX - 0.05), height: 0.62), note: "ISO 18013 portrait zone"))
        default:
            break
        }
    }

    // MARK: Merge

    /// One box per thing: overlapping boxes of the same kind are joined.
    func merged() -> [Finding] {
        var out: [Finding] = []
        for f in findings {
            if let i = out.firstIndex(where: { $0.kind == f.kind && ($0.rect.intersectionArea(f.rect) > 0.5 * min($0.rect.area, f.rect.area)) }) {
                out[i].rect = out[i].rect.union(f.rect)
                if !out[i].note.contains(f.note) { out[i].note += ", " + f.note }
            } else {
                out.append(f)
            }
        }
        return out
    }
}
