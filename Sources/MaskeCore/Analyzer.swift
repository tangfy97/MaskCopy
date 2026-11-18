import CoreGraphics
import Foundation
import CoreML
import Vision

/// Reads one page of a document and suggests what to hide. Everything runs on the device.
public struct Analyzer {
    public init() {}

    /// Finds the document in a photo, straightens it, and analyzes it.
    public func analyze(photo: CGImage) throws -> (DocumentImage, PageAnalysis) {
        var doc = Rectifier.straighten(photo)
        var observations = try recognize(doc.image, expectedLines: doc.quickLines)
        // The quick read can choose an inverted page because Vision still reads the text.
        // A consistent backward direction in the full read is stronger evidence.
        if Self.isUpsideDown(observations.lines), let upright = Rectifier.halfTurn(doc),
           let reread = try? recognize(upright.image, expectedLines: doc.quickLines),
           !reread.lines.isEmpty, !Self.isUpsideDown(reread.lines) {
            doc = upright
            observations = reread
        }
        var frames: [Quad] = []
        if doc.corners != Quad(CGRect(x: 0, y: 0, width: 1, height: 1)) {
            // Resampling can lose a thin photo border. Keep frames measured before page
            // correction, transformed through the same mapping as the corrected pixels.
            frames = PortraitDetector.detectFrames(in: photo).compactMap { frame in
                let corners = Rectifier.rotated(frame, quarterTurns: doc.quarterTurns).points.compactMap(doc.toSource.unapply)
                guard corners.count == 4 else { return nil }
                let mapped = Quad(tl: corners[0], tr: corners[1], br: corners[2], bl: corners[3])
                return mapped.isConvex ? mapped : nil
            }
        }
        return (doc, analyze(doc.image, fillsFrame: doc.fillsFrame, observations: observations, sourceFrames: frames))
    }

    /// Analyzes an upright image. `fillsFrame` says the image is the document edge to edge,
    /// which lets layout rules use the image's edges.
    public func analyze(_ image: CGImage, fillsFrame: Bool = false, expectedLines: Int = 0) throws -> PageAnalysis {
        try analyze(image, fillsFrame: fillsFrame, observations: recognize(image, expectedLines: expectedLines))
    }

    private typealias Observations = (lines: [TextLine], faces: [CGRect], barcodes: [(Quad, String?)])

    private static func isUpsideDown(_ lines: [TextLine]) -> Bool {
        let lines = lines.filter { $0.text.count >= 3 }
        let reversed = lines.filter { line in
            let across = minus(line.quad.tr, line.quad.tl)
            return across.x < -abs(across.y)
        }
        return reversed.count >= 2 && reversed.count * 5 >= lines.count * 4
    }

    private func analyze(_ image: CGImage, fillsFrame: Bool, observations: Observations, sourceFrames: [Quad] = []) -> PageAnalysis {
        let aspect = CGFloat(image.width) / CGFloat(max(image.height, 1))
        var (lines, faces, barcodes) = observations
        let (mrz, mrzLines) = readMRZ(in: image, lines: &lines)
        var page = Page(lines: lines, aspect: aspect)
        page.fillsFrame = fillsFrame
        page.luma = Luma(image)

        // 1. Machine-readable zone: the most reliable thing on a passport or ID card.
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
        let numbered = Self.isNumberedLayout(folded)
        var kind = mrz?.documentKind ?? Self.keywordKind(folded) ?? (numbered ? .drivingLicence : .unknown)
        if kind == .unknown, numbered { kind = .drivingLicence }
        // Multilingual security print on EU licences can name a different country's licence.
        let licenceHeading = kind == .drivingLicence
            ? Self.keywordCountry(lines.filter { $0.box.midY < 0.3 }.map { $0.text.foldedUpper }) : nil
        let country = mrz.flatMap { Countries.country(mrzCode: $0.issuingState) }
            ?? licenceHeading ?? Self.keywordCountry(folded) ?? Self.strongPatternCountry(page)
        // The back of the Egyptian national ID has no title; its national number names the country.
        if kind == .unknown, country?.code == "EG" { kind = .idCard }
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
        if kind == .drivingLicence || kind == .unknown { page.findFieldCodes(numbered: numbered) }
        if kind != .passport { page.findStandaloneNumbers() }
        if country?.region != .middleEast,
           kind == .idCard || kind == .residencePermit || mrz?.format == .td1 || country?.region == .europe && kind == .unknown {
            page.findCardAccessNumber()
        }
        if country?.code == "EG", kind == .idCard { page.findEgyptianIDAddress() }
        let streetCountries: Set<String> = ["US", "CA", "AU", "NZ", "GB", "IE", "SG", "MY", "DE", "NL", "AT", "CH", "BE", "LU", "FR"]
        if country.map({ streetCountries.contains($0.code) }) ?? true {
            page.findStreetAddresses()
        }

        // 6. Photos and barcodes.
        let portraits = PortraitDetector(image: image, sourceFrames: sourceFrames)
        if kind == .passport { faces.append(contentsOf: portraits.passportFaces(excluding: faces)) }
        for face in faces {
            let estimate = page.photoEstimate(around: face)
            let bounds = page.photoBounds(around: face, within: estimate)
            let search = page.photoBounds(around: face, within: estimate.insetBy(dx: 0, dy: -face.height * 0.35).clampedToUnit())
            if let edge = portraits.frame(near: Quad(estimate), face: face, bounds: bounds) {
                page.findings.append(Finding(kind: .photo, quad: edge, note: "face, portrait edge"))
            } else if var measured = portraits.borderlessBounds(face: face, within: search, text: lines.map(\.box)) {
                if country?.code == "NL", kind == .drivingLicence, face.midX < 0.4,
                   let row = mrzLines.first, MRZReader.normalize(row.text).hasPrefix("D1NLD"),
                   abs(row.quad.tr.y - row.quad.tl.y) < row.box.width * 0.03 {
                    // The D1 Dutch licence's pale left shoulder is printed over the card's
                    // pink security pattern. Its measured ink can look like background.
                    // Calibrated against the official specimen, relative to its MRZ start,
                    // so this never uses the edges of an unrectified input photograph.
                    let left = max(0, row.quad.tl.x - row.box.width * 0.025)
                    if left < measured.minX, measured.minX - left < face.width * 0.35 {
                        measured = CGRect(x: left, y: measured.minY, width: measured.maxX - left, height: measured.height)
                    }
                }
                page.findings.append(Finding(kind: .photo, rect: measured, note: "borderless portrait bounds"))
            } else {
                page.findings.append(Finding(kind: .photo, rect: bounds, note: "face estimate"))
            }
        }
        if faces.isEmpty {
            page.addLayoutPhoto()
            for i in page.findings.indices where page.findings[i].kind == .photo {
                let photo = page.findings[i]
                if let edge = portraits.frame(near: photo.shape, face: nil, bounds: nil) {
                    page.findings[i] = Finding(kind: .photo, quad: edge, note: photo.note + ", portrait edge")
                }
            }
        }
        for window in portraits.windows(country: page.country, kind: kind, existing: page.findings) {
            page.findings.append(Finding(kind: .photo, quad: window, note: "portrait window edge"))
        }
        for (quad, _) in barcodes { page.add(.barcode, quad, padding: 0.02, note: "barcode", fit: false) }
        // The PDF417 on the back of North American licences and ID cards (AAMVA).
        if kind == .unknown, barcodes.contains(where: { $0.1?.contains("ANSI ") == true }) { kind = .drivingLicence }

        return PageAnalysis(kind: kind, country: country, mrz: mrz, findings: page.merged(), lines: lines.map { String(format: "%@  [%.3f %.3f %.3f %.3f]", $0.text, $0.box.minX, $0.box.minY, $0.box.width, $0.box.height) })
    }

    // MARK: Vision

    private func recognize(_ image: CGImage, expectedLines: Int = 0) throws -> Observations {
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

    /// A whole-page OCR pass can omit both passport MRZ rows. Retry on the bottom
    /// of the actual pixels so Vision only has to read the machine-readable text there.
    private func readMRZ(in image: CGImage, lines: inout [TextLine]) -> (MRZ?, [TextLine]) {
        let original = MRZReader.find(in: lines)
        guard original.0?.checksumsValid != true,
              Self.keywordKind(lines.map { $0.text.foldedUpper }) == .passport
                || original.1.contains(where: { MRZReader.normalize($0.text).count >= 40 }) else { return original }
        let top = image.height * 5 / 8
        guard let crop = image.cropping(to: CGRect(x: 0, y: top, width: image.width, height: image.height - top)) else { return original }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        // Small scans (about 600 px wide) leave MRZ characters too small for Vision to find.
        // Normalized coordinates are unchanged by enlarging the crop.
        let bottom = crop.width < 1600 ? (Self.enlarged(crop, to: 2000) ?? crop) : crop
        try? perform(request, on: bottom)
        let recovered = Self.lines(from: request.results ?? []).map { line in
            let quad = line.quad.mapped { point in
                CGPoint(x: point.x, y: (CGFloat(top) + point.y * CGFloat(crop.height)) / CGFloat(image.height))
            }
            return TextLine(text: line.text, quad: quad, candidate: nil)
        }
        let retry = MRZReader.find(in: recovered)
        let result: (MRZ?, [TextLine])
        if retry.0?.format == .td3, retry.0?.checksumsValid == true {
            result = retry
        } else {
            let fullRows = MRZReader.passportRows(in: lines)
            let cropRows = MRZReader.passportRows(in: recovered)
            let rows = fullRows.isEmpty ? cropRows : fullRows
            if !rows.isEmpty {
                // The name can be noisy while the number row still passes its check digits.
                let parsed = MRZReader.parse(rows.map { MRZReader.normalize($0.text) })
                result = (parsed?.checksumsValid == true ? parsed : nil, rows)
            } else if retry.0?.format == .td3, retry.1.count > original.1.count {
                result = retry
            } else {
                return original
            }
        }
        lines.removeAll { line in
            result.1.contains { $0.box.intersectionArea(line.box) > line.box.area * 0.5 }
        }
        lines.append(contentsOf: result.1)
        if Page.debug { print("  · MRZ retry: found \(result.1.count) rows") }
        return result
    }

    static func enlarged(_ image: CGImage, to width: Int) -> CGImage? {
        let height = Int((CGFloat(image.height) * CGFloat(width) / CGFloat(max(image.width, 1))).rounded())
        guard height > 0, let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
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

    /// For part of a line that runs to one end of it: how many words it has, and which end on the
    /// page (`fromEnd`: the right). The ink fit then drops anything (a label) that Vision's box took
    /// in from the other side. On a right-to-left (Arabic) line the end of the text is on the left.
    func words(_ range: Range<String.Index>, in line: TextLine) -> (count: Int, fromEnd: Bool)? {
        let n = line.text[range].split(whereSeparator: \.isWhitespace).count
        let atStart = range.lowerBound == line.text.startIndex, atEnd = range.upperBound == line.text.endIndex
        let rtl = line.text.isRightToLeft
        if atEnd && !atStart { return (n, !rtl) }
        if atStart && !atEnd { return (n, rtl) }
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
            let inside = line.text[range].reduce(0) { $0 + InkFit.advance($1) }
            let cut = line.cutPoint(at: range.lowerBound == line.text.startIndex ? range.upperBound : range.lowerBound)
            // The part is at one end of the line on the page, so it starts (or ends) where the
            // rest of the line's characters end.
            if total > 0, let part = InkFit.fitPart(of: line.quad, in: luma,
                                                  boundary: w.fromEnd ? 1 - inside / total : inside / total,
                                                  cut: cut, keepEnd: w.fromEnd) {
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
            var matches: [(range: Range<String.Index>, kind: FindingKind, label: String)] = []
            for (kind, labels) in Labels.rules {
                for label in labels where label != "FIN" || country == nil || country == "SG" {
                    for r in tokenRanges(of: label, in: v.value) {
                        if let o = v.originalRange(r) { matches.append((o, kind, label)) }
                    }
                }
            }
            // A label inside a longer one ("رقم الهوية" in "رقم الهوية الوطنية") is the longer one.
            let all = matches
            matches.removeAll { m in all.contains { $0.range != m.range && $0.range.lowerBound <= m.range.lowerBound && $0.range.upperBound >= m.range.upperBound } }
            for m in matches {
                // A value ends where the next label on the line begins ("ID No. 2123456788 رقم الهوية").
                let end = matches.map(\.range.lowerBound).filter { $0 >= m.range.upperBound }.min()
                addValue(after: m.range, in: line, index: index, among: lines, kind: m.kind, note: "label \(m.label)", end: end)
            }
        }
    }

    /// The value of a label: the rest of its line, or the text beside it (to the right, or to the
    /// left of an Arabic label), or the line below.
    mutating func addValue(after label: Range<String.Index>, in line: TextLine, index: Int, among lines: [TextLine], kind: FindingKind, note: String,
                           end: String.Index? = nil) {
        let lineEnd = end ?? line.text.endIndex
        let rest = line.text[label.upperBound..<lineEnd]
        let skip = CharacterSet(charactersIn: " .:/#№：-").union(.whitespaces)
        if let start = rest.unicodeScalars.firstIndex(where: { !skip.contains($0) }) {
            var stop = lineEnd
            while stop > start, let c = line.text[..<stop].unicodeScalars.last, skip.contains(c) {
                stop = line.text.unicodeScalars.index(before: stop)
            }
            let valueRange = start..<stop
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
        // A bilingual label can be split vertically while OCR merges its smaller English
        // translation with the CJK value ("住址" above "Adtre北京"). Keep only the value.
        if kind == .address, String(line.text[label]).containsCJK {
            for candidate in lines.sorted(by: { abs($0.box.midY - labelBox.midY) < abs($1.box.midY - labelBox.midY) }) {
                let box = candidate.box
                guard abs(box.minX - labelBox.minX) < max(0.015, labelBox.width * 0.35),
                      box.midY >= labelBox.midY, box.midY < labelBox.maxY + labelBox.height * 0.75,
                      box.height < labelBox.height * 2,
                      box.maxX > labelBox.maxX + labelBox.height * 0.2 / aspect,
                      let first = candidate.text.firstIndex(where: { String($0).containsCJK }) else { continue }
                let prefix = candidate.text[..<first]
                guard prefix.filter(\.isLetter).count >= 2,
                      prefix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isWhitespace || $0.isPunctuation) }),
                      looksLikeValue(String(candidate.text[first...]), kind) else { continue }
                let range = first..<candidate.text.endIndex
                addPart(kind, of: candidate, range, note: note + " (bilingual)")
                addContinuation(below: candidate.box(for: range), among: lines, note: note)
                return
            }
        }
        // Beside it on the same line: to the right, or to the left of an Arabic label.
        let beside: TextLine?
        if String(line.text[label]).containsArabic {
            beside = lines.filter({ abs($0.box.midY - labelBox.midY) < labelBox.height * 0.6 && $0.box.maxX <= labelBox.minX + 0.005 && labelBox.minX - $0.box.maxX < 0.3 && looksLikeValue($0.text, kind) })
                .max(by: { $0.box.maxX < $1.box.maxX })
        } else {
            beside = lines.filter({ abs($0.box.midY - labelBox.midY) < labelBox.height * 0.6 && $0.box.minX >= labelBox.maxX - 0.005 && $0.box.minX - labelBox.maxX < 0.3 && looksLikeValue($0.text, kind) })
                .min(by: { $0.box.minX < $1.box.minX })
        }
        if let right = beside {
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
        // On Chinese licences the issuer's stamp can sit just below the address.
        let maxGap: CGFloat = country == "CN" && kind == .drivingLicence ? 0.85 : 1.7
        for _ in 0..<2 {
            guard let next = lineBelow(current, among: lines, maxGap: maxGap) else { return }
            let folded = next.text.foldedUpper
            if Analyzer.fieldCode(of: folded) != nil || Labels.rules.contains(where: { $0.1.contains { folded.hasPrefix($0) } })
                || Labels.otherFields.contains(where: { folded.hasPrefix($0) }) { return }
            // Another field: a full date ("2030/01/01", "08/31/2030").
            let digits = MappedText(next.text, dropSpaces: false).value
            if digits.range(of: #"\d{4}[./-]\d{1,2}[./-]\d{1,2}|\d{1,2}[./-]\d{1,2}[./-]\d{4}"#, options: .regularExpression) != nil { return }
            add(.address, next.quad, note: note + " (continued)")
            current = next.box
        }
    }

    // MARK: Numbered licence fields

    mutating func findFieldCodes(numbered: Bool) {
        let lines = textLines
        for (index, line) in lines.enumerated() {
            let folded = line.text.foldedUpper
            guard let (code, _) = Analyzer.fieldCode(of: folded) else { continue }
            // Norwegian licences print 4b and 4d side by side. Vision sometimes reads "4d" as "Ad".
            if country == "NO", numbered, code == "4B",
               let field = line.text.range(of: #"(?i)(?<=\s)[4A]D[.:\s]+[0-9]{11}\s*$"#, options: .regularExpression),
               let value = line.text.range(of: #"[0-9]{11}"#, options: .regularExpression, range: field) {
                addPart(.personalNumber, of: line, value, note: "field 4D")
            }
            guard var kind = Labels.fieldCodes[code] else { continue }
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
            // Dates, also in Arabic-Indic digits and with the holder's sex after them ("17 AUG 1958 F").
            let folded = MappedText(line.text, dropSpaces: false).value
            if Self.date.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)) != nil { continue }
            // A number after the name of a field that is not secret (a company or tax-class number).
            let upper = line.text.foldedUpper
            if Labels.keptNumbers.contains(where: { upper.hasPrefix($0) }) { continue }
            let digits = t.filter(\.isNumber).count, letters = t.count - digits
            // A number another rule already masks (the Egyptian national number) is not a second finding.
            if findings.contains(where: { $0.rect.intersectionArea(line.box) > 0.5 * line.box.area }) { continue }
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

    // MARK: Egyptian national ID

    /// The front of the Egyptian national ID prints the address without a label: under the
    /// heading, the name on two lines, then the address on the lines below it, above the
    /// national number.
    mutating func findEgyptianIDAddress() {
        let lines = textLines
        // The national number, or a long run of digits where OCR dropped some of them.
        let numberPattern = try! NSRegularExpression(pattern: #"\d{10,}"#)
        guard let number = lines.filter({ !MappedText($0.text, dropSpaces: true).matches(numberPattern).isEmpty })
            .max(by: { $0.box.midY < $1.box.midY }) else { return }
        let headings = ["جمهورية مصر العربية", "بطاقة تحقيق الشخصية", "تحقيق الشخصية", "ARAB REPUBLIC OF EGYPT"].map(\.foldedUpper)
        let isHeading = { (l: TextLine) in headings.contains { l.text.foldedUpper.contains($0) } }
        let headingBottom = lines.filter(isHeading).map(\.box.maxY).max() ?? 0
        // The stack of Arabic lines directly above the number, in the number's column.
        var stack: [TextLine] = []
        var current = number.box
        while let next = lines.filter({ l in
            l.text.containsArabic && !isHeading(l) && l.box.minY >= headingBottom - 0.005
                && l.box.maxY <= current.minY + current.height * 0.3
                && current.minY - l.box.maxY < max(l.box.height, current.height) * (stack.isEmpty ? 6 : 2.2)
                && l.box.maxX > number.box.minX && !stack.contains { $0.box == l.box }
        }).max(by: { $0.box.maxY < $1.box.maxY }) {
            stack.insert(next, at: 0)
            current = next.box
        }
        log("EG ID body lines: \(stack.map(\.text))")
        let address: ArraySlice<TextLine>
        if headingBottom > 0 {
            // The name sits just under the heading and the address in the lower part of the space
            // down to the number, so a name line OCR misses doesn't move the address up.
            let span = number.box.minY - headingBottom
            address = stack.filter { ($0.box.midY - headingBottom) / span > 0.4 }[...]
        } else {
            // Without the heading: the first two lines are the name; anything below them is the address.
            address = stack.dropFirst(2)
        }
        for line in address { add(.address, line.quad, note: "EG ID address") }
    }

    // MARK: Street addresses without a label

    static let date = try! NSRegularExpression(pattern:
        #"^\s*(?:\d{1,2}[ ./-]*(?:[A-Z]{3,5}|\d{1,2})[ ./-]*\d{2,4}|\d{4}[ ./-]*\d{1,2}[ ./-]*\d{1,2})(?:\s+[MFX])?\s*$"#)

    static let street = try! NSRegularExpression(pattern:
        #"^(?:BLK |BLOCK |NO\.? ?|LOT |UNIT )?\d{1,5}[A-Z]?[ ,/-]+(?:[A-Z0-9'.-]+ )*(?:ST|STREET|RD|ROAD|AVE|AVENUE|DR|DRIVE|LN|LANE|BLVD|WAY|CT|COURT|PL|PLACE|CRES|CRESCENT|HWY|TCE|TERRACE|PDE|PARADE|CL|CLOSE|SQ|GROVE|GR)\b|\b(?:JALAN|JLN|LORONG|TAMAN|PERSIARAN)\b|^\d{1,5}[A-Z]?,? (?:RUE|BOUL|BOULEVARD|BOUL\.|AV\.?|AVENUE|CH\.?|CHEMIN|RANG|ROUTE|RTE|MONTEE|COTE|IMPASSE|ALLEE|PROMENADE|PLACE) |^[A-Z][A-Z'.-]*(?: [A-Z][A-Z'.-]*)*(?:STRASSE|STR\.|STRAAT|WEG|LAAN|PLEIN|GRACHT|KADE|DIJK|SINGEL|ALLEE|PLATZ|RING|GASSE|DAMM) \d{1,5} ?[A-Z]?(?:[ -]\d{1,4})?(?: ?[A-Z]{1,3})?,?$"#)
    static let postcodeLine = try! NSRegularExpression(pattern:
        #"^\d{4,6} [A-Z]{3,}|^\d{4} ?[A-Z]{2} [A-Z]{2,}|\b(?:[A-Z]{2,3} \d{4,5}(?:-\d{4})?|\d{4,6})$|\b[A-Z]\d[A-Z] ?\d[A-Z]\d$|\b[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$"#)

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
    func photoEstimate(around face: CGRect) -> CGRect {
        let h = face.height * 2.05
        let w = max(face.width, min(face.width * 1.75, h / aspect * 0.95))
        return CGRect(x: face.midX - w / 2, y: face.minY - face.height * 0.55, width: w, height: h).clampedToUnit()
    }

    /// Several separate rows beside a face are evidence of a text column. Stop the photo
    /// before that column, while keeping a buffer around the whole face. A single OCR box
    /// could be a watermark across the portrait and never sets a limit on its own.
    func photoBounds(around face: CGRect, within estimate: CGRect) -> CGRect {
        let faceBand = face.insetBy(dx: 0, dy: -face.height * 0.22)
        let beside = textLines.map(\.box).filter {
            $0.midY > faceBand.minY && $0.midY < faceBand.maxY
                && $0.height < face.height * 0.28 && $0.width > face.width * 0.2
        }
        let buffer = face.width * 0.12
        let right = beside.filter { $0.minX >= face.maxX + buffer && $0.minX < estimate.maxX }
        let left = beside.filter { $0.maxX <= face.minX - buffer && $0.maxX > estimate.minX }
        func columnEdge(_ rows: [CGRect], at edge: KeyPath<CGRect, CGFloat>, outward: CGFloat) -> CGFloat? {
            let nearest = rows.sorted { outward * $0[keyPath: edge] < outward * $1[keyPath: edge] }
            return nearest.first { row in
                nearest.contains {
                    abs($0.midY - row.midY) > max($0.height, row.height)
                        && abs($0[keyPath: edge] - row[keyPath: edge]) < face.width * 0.25
                }
            }?[keyPath: edge]
        }
        let minX = columnEdge(left, at: \.maxX, outward: -1) ?? estimate.minX
        let maxX = columnEdge(right, at: \.minX, outward: 1) ?? estimate.maxX
        let below = textLines.map(\.box).filter {
            $0.minY > face.maxY + face.height * 0.1 && $0.minY < estimate.maxY
                && $0.height < face.height * 0.28 && $0.width > face.width * 0.5
                && $0.maxX > minX && $0.minX < maxX
        }.map(\.minY).min()
        let bottom = below.map { $0 - face.height * 0.03 } ?? estimate.maxY
        return CGRect(x: minX, y: estimate.minY, width: maxX - minX, height: bottom - estimate.minY)
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
