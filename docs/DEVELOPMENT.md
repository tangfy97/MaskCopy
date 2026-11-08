# MaskCopy — development notes

## How the engine works

`Analyzer.analyze(photo:)` in `Sources/MaskeCore` takes a photo and:

1. **Straightens the document** (`Rectifier`). A quick read of the photo each way up scores the text, with a bonus for readable MRZ lines. Vision's document outline is accepted only if most of that text is inside it, so the portrait or a barcode is never taken for the document. The document is then perspective-corrected. If most text boxes in the full read point backward, turn the page 180° and read it again. What the user reviews and shares is this straightened document.
2. **Finds what to hide** on it with the rules below.
3. **Fits every text mask to the ink** (`InkFit`). Projectively sample each four-cornered text box into a local patch, measure and level its ink there, then map all mask corners back through the same homography. This retains residual taper. A turn must tighten the band without losing end ink. If the band extends into adjacent rows, use the OCR box with a margin. For a value on the same line as its label, use distinct Vision character boxes when available, then fall back to estimated character widths.

Debugging: `MASKE_DEBUG=1 maske analyze <image>` prints how each mask was made; `maske ocr <image>` compares text recognition in memory and from a file (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md)).

## How the engine finds what to hide

The rules work on the straightened page. It does not rely on a template per country: almost every document follows one of a few international standards, and the rules below work from those.

| Step | What it looks for | Standard it relies on |
|---|---|---|
| Machine-readable zone | The bottom-most run of lines of `A–Z 0–9 <`, read as TD3 (passports), TD1 (ID cards, residence permits), TD2, or a licence line. For an incomplete passport result, retry OCR in a crop and use aligned rows to cover text that could not be parsed | ICAO 9303, ISO 18013, Dutch eDL reading manual |
| Kind and country | The MRZ's issuing state; otherwise words printed on the document (`KONINKRIJK DER NEDERLANDEN`, `居民身份证`, US state names…); otherwise a number only one country uses | |
| Personal and document numbers | About 45 national formats, each a pattern plus its check (BSN 11-proef, fødselsnummer, PESEL, codice fiscale, 身份证号, NRIC, HKID, CURP…), in `NumberPatterns.swift` | National rules |
| Values from the MRZ | The document and personal numbers read from the MRZ, wherever else they are printed | ICAO 9303 |
| Labelled fields | Labels in many languages (`Persoonsnummer`, `Personal No.`, `住址`, `주소`…) and the value to their right or below, in `Labels.swift` | |
| Numbered licence fields | `4d` personal number, `5` licence number, `8` address | EU Directive 2006/126/EC, ISO/IEC 18013-1, AAMVA |
| Unlabelled numbers | A line that is one code mixing letters and digits, or 7+ digits (not a date) | |
| Card access number | A six-digit line on an ID card | EU Regulation 2019/1157 cards |
| Street addresses | `12 GEORGE ST`, `NO 12 JALAN …` and the postcode line below | |
| Photo | Verified frames containing a face; otherwise connected portrait bounds limited by neighbouring fields. Retry small passport faces in an enlarged crop. Separate feature rules cover reviewed Dutch/Norwegian windows; the Dutch D1 licence's pale shoulder is anchored to its MRZ. If no face is found, try the passport portrait zone or field 6 of a licence | ICAO 9303, ISO 18013; local specimen calibration for feature rules |
| Barcodes | Every barcode, including the PDF417 on the back of North American cards (AAMVA) | |

Weak patterns (plain digit strings with a check digit) only run for their own country, or when the country is unknown; distinctive ones run everywhere. Overlapping boxes of the same kind are merged. Every box can be undone in the app, so the engine leans towards hiding too much.

## Adding a country

1. Add it to `Countries.all` with its MRZ code and the documents it issues, and add the words that name it to `Countries.keywords`.
2. Add its personal-number format to `NumberPattern.all` and the check to `Checksum`, with a published example in `ChecksumTests`.
3. Add its field labels to `Labels`.
4. Add a synthetic document to `Fixtures.all` in `Sources/maske/Fixtures.swift`, marking which text must be hidden (`.hide`) and which must stay (`.keep`). Use `"Label |value"` when only the value is to be hidden.
5. Run `scripts/check.sh`.

## Testing

`maske fixtures` draws 43 synthetic documents (made-up people with valid check digits) across Europe, North America, Oceania and Asia, each on a dark table so finding its edges is part of the test, and `expected.json` with the exact ink bounds of every field that must be hidden or kept. Portraits can now contain multiple annotated frames, including windows. `maske eval` reports:

- **Coverage:** a field counts as hidden only when at least 98% of its ink is under a mask.
- **Kept:** a field that must stay visible may have at most 10% covered.
- **Precision:** how much of each mask lies on its field (with a tolerance of about an eighth of the text height). 1.0 means no excess.

Every run writes masked copies and overlays (green: the field's ink, red: the masks) to `Fixtures/synthetic/out`. A missing fixture or a field that fails the coverage or visibility threshold makes the command fail.

`maske warp <dir> <out>` makes five photo-like copies of each image (tilted, rotated, turned 90°, upside down, steep). Run `maske angles <out> <dir>/expected.json` to project the known field boxes onto each copy and check coverage and visibility. For unlabelled specimens, `maske angles <out>` compares the copy with the original's masks to check consistency.

Real specimens: `scripts/fetch_specimens.py` collects specimens from Wikimedia Commons; PRADO (the Council of the EU's register) images were collected through the browser. Both go in `Fixtures/specimens/`, which is not committed, since the images are not ours to publish. `maske review <dir> <out>` masks every image in a folder for looking through by eye. Status and open problems: [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

`maske eval Fixtures/specimens Fixtures/specimen-focus.json` checks the seven annotated Dutch, Norwegian and Chinese specimens. The manifest contains field rectangles and specimen file identifiers, not pixels or copied personal data. Missing specimen images fail the check. Coverage is sampled against hand annotations; inspect the overlays and exported edges too.

## Review and rendering

Review and export use the same polygon and opaque blue-grey fill. Tap a mask for the four-corner editor; its translucent adjustment preview is only in memory. Save updates the polygon, Cancel leaves the original unchanged, and native scrolling and 1–8× zoom support small windows. The visible controls carry the interaction; explanatory paragraphs are intentionally omitted. Run `scripts/ui-check.sh` with a booted Simulator to exercise the actual editor and export, using a generated synthetic passport.

The app's session owns cancellable import and analysis tasks, guarded by a document generation ID. Decoding runs off the main actor. Cancellation prevents stale publication and skips further pages, but a synchronous Vision request already running can finish offscreen. Page edits update a revision ID. Share's preview key includes those revisions, the document generation and trimmed recipient/purpose; only a matching preview can be shared. Preview rendering stays in memory. An explicit Share writes into its own temporary subdirectory, so a cancelled attempt cannot delete a newer attempt's file. Session cleanup and the next launch remove abandoned copies. `MaskeAppTests` covers cancellation and file ownership; `MaskeUITests` covers the actual journey, keyboard and system share sheet. See [DESIGN.md](DESIGN.md) and [AUDIT.md](AUDIT.md) for the interface direction and rendered checks.

The exported JPEG has a wrapping recipient/purpose/date footer outside the document and one light diagonal recipient mark per page. The renderer no longer adds a separate thick stroke beyond the reviewed polygon. Opacity is checked by rendering different underlying images under the same full mask and comparing the output pixels.

## Known limits

- In the iOS Simulator, Vision runs on the CPU and face and barcode detection may find nothing, so check those on a device. On the Mac and on devices they work.
- The drawn portraits in the synthetic documents aren't faces to Vision; the photo on ID cards is only found when a real face is there.
- Signatures are not detected; draw a box.
- No reading of the chip (NFC): it isn't needed to make a copy.

## MaskCopy workflow (build 6)

The installed product is MaskCopy.app; the legacy project, target, modules and bundle ID stay stable. Session.Step now includes review, share (watermark entry) and preview (final copy). Watermark text is local state until leaving that screen or preparing a copy. `Session.prepareCopy` owns background rendering and a cache stamp containing the document ID, page revisions and trimmed input. Old/cancelled work cannot publish; page edits invalidate the image. The date is fixed for the session. The ready screen retains its rendered image while navigating away, and its own privacy cover shields it when inactive.

DocumentViewport wraps UIScrollView with an installed UIImageView, a vector overlay and four native corner controls. UIScrollView applies zoom transforms rather than relaying out a resizable SwiftUI bitmap. Inverse handle transforms preserve a 44-point hit target while zooming. Pan deltas convert through image coordinates and remain clamped/convex. Native double-tap and pinch are covered by UI checks.

Renderer paints opaque charcoal, then draws the watermark in dark ink on the document and light ink clipped to redactions. Recipient, purpose and date stay inside each page. `RenderCopy` signposts expose timing without document contents. The copy stays in memory until Share creates a metadata-free JPEG.

## Direct manipulation and PDF export (revision 7)

`Quad.translated(by:)` clamps translation once for the whole polygon, preserving its dimensions and perspective. Review applies it from a captured gesture-start polygon. The native editor uses a polygon-shaped hit target beneath the corner controls; dragging its body moves the polygon, while dragging outside pans the UIScrollView. Both paths mutate the same findings used for rendering and invalidate the revision-bound copy cache.

Exporter accepts JPG/PDF. PDF embeds only the freshly encoded, flattened JPEG in a minimal one-page PDF object graph. It has no Info dictionary, original source image, text objects, annotations, JavaScript or mask layer. The final inspected composite remains the exact content of either format; separate pages per source side are deferred. Cancellation, protected temporary-file writes and independent attempt directories apply to both formats. The native Files picker copies the selected file to a user-chosen location; that saved destination is not app history and is not removed with temporary working files.
