# Known issues

What is known to be wrong or unverified in the prototype, why, and what to try next. Fix these one at a time; each fix comes with a check in `scripts/check.sh` or a note on how it was verified.

Status on 7 November 2026 (0.1.0, build 2), synthetic documents (`maske eval Fixtures/synthetic`):
109/110 sensitive fields fully covered, 94/94 fields that must stay visible left visible, mask precision 0.96 on average (worst 0.80), document kind and country right on 41/41 when text recognition is complete.

## Open

### 1. Text recognition sometimes misses lines (most important)

**What happens:** On the same straightened image, `VNRecognizeTextRequest` (accurate) returns 17 lines in a standalone script but only 13 inside the `maske` process, in particular missing both MRZ lines of the synthetic Norwegian, Dutch and Singaporean passports. When the MRZ is missing, the MRZ mask, the country and the passport photo position (which is measured from the MRZ) are all lost.

**What was ruled out:** the image itself (a PNG of it reads 17 lines in a script), the request settings (all revisions and language settings read 17 in a script), earlier fast reads, document segmentation, rectangle and face requests, Core Image use, and the deployment target (a script built for macOS 15 also reads 17). It also changed over time in the same process: earlier runs read 17.

**Current mitigation:** if the full read finds fewer than 80% of the lines the quick read found, it reads again (up to twice). This does not catch the case above, where the quick read also finds about 13.

**Next:** reproduce on an iPhone; compare a fresh `VNImageRequestHandler` per request against a `VNSequenceRequestHandler`; add a targeted second pass on the bottom third of passport-shaped pages with `recognitionLanguages = ["en-US"]` when no MRZ is found; log the line count per pass in debug builds.

### 2. Barcodes and faces are not detected in the iOS Simulator

The Simulator has no Neural Engine; Vision falls back to the CPU and the face, barcode and document-outline requests return nothing (no error). So in the Simulator a photo is not cropped to the document (the table stays in the picture), although the text masks still land right. On the Mac and, by design, on devices they work. **Unverified on an iPhone:** the PDF417 on the back of US and Canadian licences. **Next:** test with a printed AAMVA sample on a device.

### 3. Portrait masks on real photos are unverified

When Vision finds a face, the portrait mask is the portrait's own rectangle if one is visible around the face, otherwise an estimate (about twice the face's height). Passports without a found face use the ICAO 9303 portrait zone measured from the MRZ. The estimate's proportions have only been checked on drawn documents, where there are no real faces. **Next:** run `maske review` on the PRADO specimens and adjust the estimate.

### 4. Labels next to values on one line

A value is separated from its label at the ink gap nearest to where the characters predict the label ends (Chinese, Japanese and Korean characters count as wider than Latin ones). Known weak spots:
- A label and value separated by a single narrow space can still be cut one character off; the cut is only accepted when the value's width matches its characters within 20%.
- In Helvetica-like typefaces the gap after a "1" is as wide as a space. A value starting with "1" right after a code ("8 123 QUEEN ST W") can lose its first digit: on the synthetic Ontario licence 96% of the address is covered.
- Mixed-script lines (Japanese label, Latin value) were the loosest masks (precision 0.85).

**Next:** use Vision's per-character boxes for the first and last character of the value when they are reliable; add fixtures with values starting with "1".

### 5. Full specimen evaluation not yet run

Collected but not yet evaluated (kept out of the repository, `Fixtures/specimens/`):
- PRADO (Council of the EU): 745 front and back images from 63 countries, newest two versions of passports, ID cards, residence permits and driving licences. These are about 600 pixels wide, much smaller than a phone photo, so recognition errors on them are partly resolution.
- Wikimedia Commons: 147 files from `scripts/fetch_specimens.py`, many of them not documents (the search matched "specimen" in plant collections). Needs filtering by document words before use.

**Next:** for the supported countries, `maske review Fixtures/specimens/prado <out>`, look through every masked copy, and turn each mistake into a rule fix and a synthetic fixture. Then `maske warp` + `maske angles` on the same specimens.

### 6. Orientation of MRZ-only pages turned 90°

The back of an ID card (mostly MRZ) photographed sideways was once straightened upside down. Orientation scoring now gives readable MRZ lines a large bonus. Verified on one case, not yet re-run across the angle test.

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
