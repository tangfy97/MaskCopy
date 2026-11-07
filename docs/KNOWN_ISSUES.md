# Known issues

What is known to be wrong or unverified in the prototype, why, and what to try next. Fix these one at a time; each fix comes with a check in `scripts/check.sh` or a note on how it was verified.

Status on 7 November 2026 (0.1.0, build 2), synthetic documents (`maske eval Fixtures/synthetic`):
109/110 sensitive fields fully covered, 94/94 fields that must stay visible left visible, mask precision 0.96 on average (worst 0.80), document kind and country right on 41/41 when text recognition is complete.

In the 8 November specimen pass, the Mac covered 111/111 sensitive fields and preserved 94/94 fields across the 41 straight fixtures. Mean precision was 0.96 and the loosest mask was the Chinese ID personal number (0.70). On 24 selected rotated and perspective fixtures the Mac covered 84/84 sensitive fields and preserved 63/63 fields. The iOS 27.0 Simulator missed the portrait and both MRZ rows on a Chinese passport turned 90°.

## Open

### 1. Text recognition sometimes misses lines (most important)

**What happens:** On the same straightened image, `VNRecognizeTextRequest` (accurate) returns 17 lines in a standalone script but only 13 inside the `maske` process, in particular missing both MRZ lines of the synthetic Norwegian, Dutch and Singaporean passports. When the MRZ is missing, the MRZ mask, the country and the passport photo position (which is measured from the MRZ) are all lost.

**What was ruled out:** the image itself (a PNG of it reads 17 lines in a script), the request settings (all revisions and language settings read 17 in a script), earlier fast reads, document segmentation, rectangle and face requests, Core Image use, and the deployment target (a script built for macOS 15 also reads 17). It also changed over time in the same process: earlier runs read 17.

**Current mitigation:** the full read retries if it finds fewer than 80% of the quick read's lines. For an incomplete passport MRZ, the engine also retries OCR on the bottom of the page and looks for two aligned rows, including OCR fragments made of fillers. This recovered both rows on the Dutch and Chinese Wikimedia passport specimens. A row Vision cannot locate in either pass can still be missed.

**Next:** reproduce on an iPhone, especially after turning the page or photographing it at a steep angle. Check incomplete TD1 runs on identity card backs separately.

### 2. Vision results differ between Simulator and device

The Simulator has no Neural Engine. On iOS 27.0 Simulator, face and outline detection returned results for some specimens. The synthetic PDF417 was still missed there and was found on the Mac. **Unverified on an iPhone:** the PDF417 on the back of US and Canadian licences. **Next:** test with a printed AAMVA sample on a device.

### 3. Portraits without a clear edge still use an estimate

When Vision finds a face, the portrait mask uses a verified rectangle if possible. The fallback uses nearby text columns to reduce spill. The German `DEU-BO-02004`, Dutch `NLD-BO-08001` and Norwegian `NOR-BO-02002` PRADO ID cards kept more of the adjacent fields in a before-and-after check. Estimates can still cover empty space around the head and shoulders. A secondary portrait printed over other fields can also overlap text.

**Next:** check borderless portraits, secondary portraits, and the passport/licence fallbacks on printed specimens with an iPhone.

### 4. Labels next to values on one line

A value is separated from its label at the ink gap nearest to where the characters predict the label ends (Chinese, Japanese and Korean characters count as wider than Latin ones). Known weak spots:
- A label and value separated by a single narrow space can still be cut one character off; the cut is only accepted when the value's width matches its characters within 20%.
- In Helvetica-like typefaces the gap after a "1" is as wide as a space. Distinct Vision character boxes now guide that cut when available. The synthetic Ontario address starting with "1" passed on the Mac after this change.
- Mixed-script lines (Japanese label, Latin value) were the loosest masks (precision 0.85).

**Next:** check cuts where Vision supplies a single box for several characters, including the Chinese personal number and mixed-script values.

### 5. Full specimen evaluation not yet run

The first comparison covered 12 public specimens from the two local collections, across the Netherlands, Norway, Germany, China and Finland. The full collections are kept out of the repository under `Fixtures/specimens/`:
- PRADO (Council of the EU): 745 front and back images from 63 countries, newest two versions of passports, ID cards, residence permits and driving licences. These are about 600 pixels wide, much smaller than a phone photo, so recognition errors on them are partly resolution.
- Wikimedia Commons: 147 files from `scripts/fetch_specimens.py`, many of them not documents (the search matched "specimen" in plant collections). Needs filtering by document words before use.

**Next:** review the remaining versions and backs for those countries, then work through the other supported countries. Use known field boxes for angle regressions where available.

### 6. Orientation and steep perspective

Vision can read upside-down text, so choosing the turn from the strings alone can leave the page inverted. This affected the address continuation on a steep Chinese ID and the MRZ on tilted Dutch ID and Chinese passport fixtures. If at least 80% of the full read's text boxes point backward, the engine now retries on the page turned 180°. The angle check measures coverage against the known positions of sensitive and preserved fields.

### 7. Speed

Each photo is read quickly four times (once each way up) to find its orientation and outline, then accurately once or more. On a loaded Mac one page took about a minute. **Not measured on an iPhone.** **Next:** time it on a device; if slow, read two orientations first and only try the others when neither reads well.

### 8. Not covered at all yet

- Signatures (draw a box).
- Machine-readable data in QR codes is masked as a barcode but not read.
- Documents from countries outside the supported list get the general rules and a warning in the app.

## Fixed in this round (for reference)

- Masks were placed relative to the photo's edges, so on any photo with background they landed in the wrong place. The document is now found and straightened first, and layout rules measure from the MRZ or the text.
- Masks were upright rectangles; on tilted text they were too big and off. They are now four-cornered shapes following the text.
- Masks were padded boxes from Vision. They are now fitted to the actual ink (with the text's own angle) plus a thin margin.
- The portrait or a barcode could be taken for the document's outline. An outline now has to contain most of the photo's text.
