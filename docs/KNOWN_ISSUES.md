# Known issues

What is known to be wrong or unverified in the prototype, why, and what to try next. Fix these one at a time; each fix comes with a check in `scripts/check.sh` or a note on how it was verified.

Status on 7 November 2026 (0.1.0, build 2), synthetic documents (`maske eval Fixtures/synthetic`):
109/110 sensitive fields fully covered, 94/94 fields that must stay visible left visible, mask precision 0.96 on average (worst 0.80), document kind and country right on 41/41 when text recognition is complete.

In the 8 November specimen pass, the Mac covered 111/111 sensitive fields and preserved 94/94 fields across the 41 straight fixtures. Mean precision was 0.96 and the loosest mask was the Chinese ID personal number (0.70). On 24 selected rotated and perspective fixtures the Mac covered 84/84 sensitive fields and preserved 63/63 fields. The iOS 27.0 Simulator missed the portrait and both MRZ rows on a Chinese passport turned 90°.

Build 4 checks: 14 unit tests; 43/43 straight synthetic documents, 121/121 sensitive fields above the 98% coverage threshold, 96/96 kept, mean precision 0.96 (worst 0.75). The Mac angle check remains 84/84 sensitive and 63/63 kept; the Simulator remains 81/84 because of that 90° Chinese passport. The UI regression verifies direct editing, zoomed dragging after scrolling, Save, Cancel and export. The new editor also has its own inactive-scene privacy cover so its source image is shielded in the app switcher.

## Open

### 1. Text recognition sometimes misses lines (most important)

**What happens:** On the same straightened image, `VNRecognizeTextRequest` (accurate) returns 17 lines in a standalone script but only 13 inside the `maske` process, in particular missing both MRZ lines of the synthetic Norwegian, Dutch and Singaporean passports. When the MRZ is missing, the MRZ mask, the country and the passport photo position (which is measured from the MRZ) are all lost.

**What was ruled out:** the image itself (a PNG of it reads 17 lines in a script), the request settings (all revisions and language settings read 17 in a script), earlier fast reads, document segmentation, rectangle and face requests, Core Image use, and the deployment target (a script built for macOS 15 also reads 17). It also changed over time in the same process: earlier runs read 17.

**Current mitigation:** the full read retries if it finds fewer than 80% of the quick read's lines. For an incomplete passport MRZ, the engine also retries OCR on the bottom of the page and looks for two aligned rows, including OCR fragments made of fillers. This recovered both rows on the Dutch and Chinese Wikimedia passport specimens. A row Vision cannot locate in either pass can still be missed.

**Next:** reproduce on an iPhone, especially after turning the page or photographing it at a steep angle. Check incomplete TD1 runs on identity card backs separately.

### 2. Vision results differ between Simulator and device

The Simulator has no Neural Engine. On iOS 27.0 Simulator, face and outline detection returned results for some specimens. The synthetic PDF417 was still missed there and was found on the Mac. **Unverified on an iPhone:** the PDF417 on the back of US and Canadian licences. **Next:** test with a printed AAMVA sample on a device.

### 3. Portraits without a clear edge still use an estimate

The current detector keeps one coordinate system for full-image rectangle observations, uses the smallest verified photo frame containing the face, and measures borderless portrait pixels within nearby field boundaries. Pale clothing on monochrome photos uses colour separation from security print. The Dutch D1 licence has an MRZ-anchored correction for its pale left shoulder, calibrated against the official specimen. This remains an estimate where there is no visible rectangular frame.

The reviewed Dutch ID/licence and Norwegian ID/licence windows are covered separately. An enlarged crop recovers the Chinese passport's small secondary face. These feature rules have not been verified for every historical version. A rectangular mask around a secondary portrait can cover text printed under that portrait; both cannot be preserved when they overlap.

**Recovery:** tap a box in Review, zoom and drag its four corners. This edits the actual export polygon. **Next:** check borderless portraits and printed specimens on an iPhone, including light clothing, glare and windows photographed against different backgrounds.

### 4. Labels next to values on one line

A value is separated from its label at the ink gap nearest to where the characters predict the label ends (Chinese, Japanese and Korean characters count as wider than Latin ones). Known weak spots:
- A label and value separated by a single narrow space can still be cut one character off; the cut is only accepted when the value's width matches its characters within 20%.
- In Helvetica-like typefaces the gap after a "1" is as wide as a space. Distinct Vision character boxes now guide that cut when available. The synthetic Ontario address starting with "1" passed on the Mac after this change.
- Mixed-script lines (Japanese label, Latin value) were the loosest masks (precision 0.85).

**Next:** check cuts where Vision supplies a single box for several characters, including the Chinese personal number and mixed-script values.

### 5. Full specimen evaluation not yet run

The first comparison covered 12 public specimens. The focused 8 November pass reviewed 28 pages from the Netherlands, Norway and China plus comparable German, French and Belgian layouts. A separate manifest annotates seven key Dutch, Norwegian and Chinese specimens: 28/28 annotated sensitive regions passed the existing coverage threshold and 15/15 annotated preserved regions stayed visible in the iOS 27 Simulator. Overall mask precision was 0.92; some number masks remain loose, particularly the Norwegian licence's field 4d. These are selected annotations, not proof that every unannotated field or document version is correct. The full collections are kept out of the repository under `Fixtures/specimens/`:
- PRADO (Council of the EU): 745 front and back images from 63 countries, newest two versions of passports, ID cards, residence permits and driving licences. These are about 600 pixels wide, much smaller than a phone photo, so recognition errors on them are partly resolution.
- Wikimedia Commons: 147 files from `scripts/fetch_specimens.py`, many of them not documents (the search matched "specimen" in plant collections). Needs filtering by document words before use.

**Next:** review the remaining versions and backs for those countries, then work through the other supported countries. Use known field boxes for angle regressions where available.

Examples still open in the visual pass: `NLD-HO-14004` residence pages have incomplete kind/country/MRZ recognition at the supplied resolution; `NOR-HO-04002` front has no country result; `CHN-HO-02001` has unknown document kind. The German `DEU-BO-02004` front document number was not masked, and secondary security portraits outside the calibrated Dutch/Norwegian families remain unverified. The focused collection has no official Chinese national-ID specimen; that layout currently has synthetic regression coverage only.

### 6. Orientation and steep perspective

Vision can read upside-down text, so choosing the turn from the strings alone can leave the page inverted. This affected the address continuation on a steep Chinese ID and the MRZ on tilted Dutch ID and Chinese passport fixtures. If at least 80% of the full read's text boxes point backward, the engine now retries on the page turned 180°. The angle check measures coverage against the known positions of sensitive and preserved fields.

### 7. Speed

Each photo is read quickly four times (once each way up) to find its orientation and outline, then accurately once or more. On a loaded Mac one page took about a minute. **Not measured on an iPhone.** **Next:** time it on a device; if slow, read two orientations first and only try the others when neither reads well.

### 8. Not covered at all yet

- Signatures (draw a box).
- Machine-readable data in QR codes is masked as a barcode but not read.
- Documents from countries outside the supported list get the general rules and a warning in the app.

### 9. Imported photos can continue without reliable rectification

Code review on 8 November: if no document outline is accepted, `Rectifier.straighten` uses the full photo. The result carries `fillsFrame = false`, but the review screen does not explain that perspective correction was unavailable. Several downstream rules still rely on horizontal rows, vertical columns or standard portrait proportions. Outline candidates are selected mainly by text inclusion, area and a broad aspect limit. Output proportions are based on photographed edge lengths, which do not establish the physical aspect ratio under perspective.

The import path also limits the whole image to 2800 pixels before finding the document. A small document within a large photo can lose useful character detail at that point.

**Next:** keep the selected image's detail until a document region is identified, validate the corrected result, and offer a four-corner adjustment or a retake when automatic rectification is uncertain. Use known card proportions only after the document family is established.

### 10. Residual text perspective: implemented, real-photo validation open

The old affine approximation has been replaced by projective sampling of each text quad. Ink fitting and levelling work in that local patch and map corners back through the same homography. A regression draws tapered glyphs and checks their corners remain covered. Invalid and crossed quads are rejected before rendering.

**Next:** verify this on photographed printed specimens on an iPhone. The change cannot recover an outline or text line Vision never found.

### 11. Detection confidence is missing from review

`Finding` records its kind, shape and debug note, but no user-facing confidence or review reason. A verified number, a face expansion and a layout estimate all appear as enabled masks. Existing masks now have a four-corner editor with 1–8× zoom, scrolling, Save, Cancel and Reset; the isolated simulator UI check covers those actions and the export preview.

**Next:** retain the evidence for each mask and highlight estimates and incomplete recognition for review. Confidence in OCR text alone does not establish confidence in the field association or mask boundary.

### 12. Evaluation does not yet establish complete redaction on real photographs

The current 98% coverage threshold samples points within field bounds. A passing field can still leave a small part uncovered. Precision excludes masks whose kind has no annotated target and masks that miss every matching target, so the mean does not capture every false positive. Most synthetic ID portraits are unannotated silhouettes and do not exercise real face detection. Only selected public specimens have been visually compared.

**Next:** annotate every intended sensitive and preserved region on a held-out set of public specimens. Check first and last characters, unnecessary masks, the final exported pixels, secondary portraits, and printed specimens photographed on an iPhone. Include low light, glare, blur, partial crops, small documents within a large photo and combined perspective/rotation. Report misses and excess separately for each condition.

## Fixed in this round (for reference)

### 13. Transform failure metadata (fixed)

If correction returns nil, `straighten` now returns the source image with full-frame identity corners, zero quarter turns and `fillsFrame = false`. It no longer retains metadata for an unapplied transform. Invalid geometry and invalid output size are covered by a regression; an actual Core Image failure after valid input has not been induced.

**Next:** pair this consistent fallback with the explicit uncertain-correction recovery described in issue 9.

- Masks were placed relative to the photo's edges, so on any photo with background they landed in the wrong place. The document is now found and straightened first, and layout rules measure from the MRZ or the text.
- Masks were upright rectangles; on tilted text they were too big and off. They are now four-cornered shapes following the text.
- Masks were padded boxes from Vision. They are now fitted to the actual ink (with the text's own angle) plus a thin margin.
- The portrait or a barcode could be taken for the document's outline. An outline now has to contain most of the photo's text.
