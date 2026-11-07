# Maske — development notes

## How the engine works

`Analyzer.analyze(photo:)` in `Sources/MaskeCore` takes a photo and:

1. **Straightens the document** (`Rectifier`). A quick read of the photo each way up says which way up it is (readable MRZ lines count heavily) and where its text is. Vision's document outline is accepted only if most of that text is inside it, so the portrait or a barcode is never taken for the document. The document is then perspective-corrected and turned upright. What the user reviews and shares is this straightened document.
2. **Finds what to hide** on it with the rules below.
3. **Fits every text mask to the ink** (`InkFit`). Around each box from Vision it looks at the pixels, finds the text's own angle from the edges of its characters, and shrinks or extends the box to the first and last ink, plus a thin margin. A value on the same line as its label is cut at the ink gap where its characters say the label ends. Masks are four-cornered shapes, so tilted text gets a tilted mask.

Debugging: `MASKE_DEBUG=1 maske analyze <image>` prints how each mask was made; `maske ocr <image>` compares text recognition in memory and from a file (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md)).

## How the engine finds what to hide

The rules work on the straightened page. It does not rely on a template per country: almost every document follows one of a few international standards, and the rules below work from those.

| Step | What it looks for | Standard it relies on |
|---|---|---|
| Machine-readable zone | The bottom-most run of lines of `A–Z 0–9 <`; read as TD3 (passports), TD1 (ID cards, residence permits), TD2, or the ISO 18013 licence line, with check digits | ICAO 9303 |
| Kind and country | The MRZ's issuing state; otherwise words printed on the document (`KONINKRIJK DER NEDERLANDEN`, `居民身份证`, US state names…); otherwise a number only one country uses | |
| Personal and document numbers | About 45 national formats, each a pattern plus its check (BSN 11-proef, fødselsnummer, PESEL, codice fiscale, 身份证号, NRIC, HKID, CURP…), in `NumberPatterns.swift` | National rules |
| Values from the MRZ | The document and personal numbers read from the MRZ, wherever else they are printed | ICAO 9303 |
| Labelled fields | Labels in many languages (`Persoonsnummer`, `Personal No.`, `住址`, `주소`…) and the value to their right or below, in `Labels.swift` | |
| Numbered licence fields | `4d` personal number, `5` licence number, `8` address | EU Directive 2006/126/EC, ISO/IEC 18013-1, AAMVA |
| Unlabelled numbers | A line that is one code mixing letters and digits, or 7+ digits (not a date) | |
| Card access number | A six-digit line on an ID card | EU Regulation 2019/1157 cards |
| Street addresses | `12 GEORGE ST`, `NO 12 JALAN …` and the postcode line below | |
| Photo | Each face, grown to the portrait around it; if no face is found, the ICAO portrait zone of a passport or field 6 of a licence | ICAO 9303, ISO 18013 |
| Barcodes | Every barcode, including the PDF417 on the back of North American cards (AAMVA) | |

Weak patterns (plain digit strings with a check digit) only run for their own country, or when the country is unknown; distinctive ones run everywhere. Overlapping boxes of the same kind are merged. Every box can be undone in the app, so the engine leans towards hiding too much.

## Adding a country

1. Add it to `Countries.all` with its MRZ code and the documents it issues, and add the words that name it to `Countries.keywords`.
2. Add its personal-number format to `NumberPattern.all` and the check to `Checksum`, with a published example in `ChecksumTests`.
3. Add its field labels to `Labels`.
4. Add a synthetic document to `Fixtures.all` in `Sources/maske/Fixtures.swift`, marking which text must be hidden (`.hide`) and which must stay (`.keep`). Use `"Label |value"` when only the value is to be hidden.
5. Run `scripts/check.sh`.

## Testing

`maske fixtures` draws 41 synthetic documents (made-up people with valid check digits) across Europe, North America, Oceania and Asia, each on a dark table so finding its edges is part of the test, and `expected.json` with the exact ink bounds of every field that must be hidden or kept. `maske eval` reports:

- **Coverage:** a field counts as hidden only when at least 98% of its ink is under a mask.
- **Kept:** a field that must stay visible may have at most 10% covered.
- **Precision:** how much of each mask lies on its field (with a tolerance of about an eighth of the text height). 1.0 means no excess.

Every run writes masked copies and overlays (green: the field's ink, red: the masks) to `Fixtures/synthetic/out`.

`maske warp <dir> <out>` makes five photo-like copies of each image (tilted, rotated, turned 90°, upside down, steep), and `maske angles <out>` checks that the masks on each copy land where they do on the original.

Real specimens: `scripts/fetch_specimens.py` collects specimens from Wikimedia Commons; PRADO (the Council of the EU's register) images were collected through the browser. Both go in `Fixtures/specimens/`, which is not committed, since the images are not ours to publish. `maske review <dir> <out>` masks every image in a folder for looking through by eye. Status and open problems: [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## Known limits

- In the iOS Simulator, Vision runs on the CPU and face and barcode detection may find nothing, so check those on a device. On the Mac and on devices they work.
- The drawn portraits in the synthetic documents aren't faces to Vision; the photo on ID cards is only found when a real face is there.
- Signatures are not detected; draw a box.
- No reading of the chip (NFC): it isn't needed to make a copy.
