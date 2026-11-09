# Roadmap

In order. Each step should end with its check in `scripts/check.sh` (or a note of how it was verified), an update to [KNOWN_ISSUES.md](KNOWN_ISSUES.md), and a CHANGELOG entry. The owner prefers small, working steps over large rewrites.

## Now: make the prototype right on real documents

1. **Norway, the Netherlands and China first.** Continue from the 28-page focused specimen pass and seven annotated specimens. Verify complete photo rectangles, pale clothing, secondary portraits and transparent windows on printed specimens photographed with an iPhone. Existing masks now have zoom and four-corner adjustment. Automatic confidence and uncertain-page recovery remain open (KNOWN_ISSUES 9, 11 and 12). Never ask for or store the owner's document photo.
2. **Extend to matching European standards.** Review comparable ID cards, licences and residence permits, then remaining supported countries. Keep version-specific failures in KNOWN_ISSUES. US/Australian layout variations are deferred at the owner's request. Expect recognition problems from the PRADO images' 600 px size.
3. **Angle test on specimens.** `maske warp` + `maske angles` on the same set; compare with the synthetic numbers.
4. **Text recognition missing lines** (KNOWN_ISSUES 1): verify the cropped passport MRZ retry already added in build 3 on a device, then address incomplete TD1 runs and other missing sensitive fields.
5. **On-device checks:** PDF417 on US/Canadian licences, real faces and the portrait mask, speed per page (target: under 2 seconds on a recent iPhone).

## Flow follow-up from the three-skill audit

- Implemented in revision 11: full imports up to four pages, explicit selection for longer PDFs/scans. Physical scanner capture still needs a device check (KNOWN_ISSUES 14).
- Implemented in revision 11: Add box opens an adjustable draft through a semantic action. Complete manual VoiceOver/Switch Control checks (KNOWN_ISSUES 15).
- Per-page watermark movement and physical multi-page/manual-add journeys are verified. The first iPhone launch/render/recognition measurements are recorded in AUDIT. Extend dense/coloured-print readability, photographed specimens and continuous gesture/frame-pacing checks; a partial trace or render microbenchmark is not a whole-session budget.

## Next: make it a 1.0

6. **Localization** to the house standard: English, English (UK), Simplified Chinese, Traditional Chinese (String Catalog). Consider Dutch and Norwegian for the main audience.
7. **Accessibility pass:** build 5 adapts source rows, document types, Review context and Share inputs to accessibility text sizes. Complete manual VoiceOver, Switch Control, Full Keyboard Access and Reduce Motion checks on an iPhone; see AUDIT.md for the rendered Simulator coverage.
8. **App Store listing:** screenshots (made from synthetic documents), description, privacy "Data Not Collected", age 4+, category Utilities, support and privacy URLs, review notes (in [APP_STORE.md](APP_STORE.md)). The account holder must accept the updated Developer Program License Agreement first.
9. **Website pages** only if the owner asks (tang-spark.no is a personal studio site).

## Later

- More supported countries, one at a time, each with a specimen review and fixtures.
- Signatures (no detection yet), QR code contents (masked, not read).
- iPad layout; Mac (Catalyst or native) using the same MaskeCore.
- Optional on-device language model (Apple Foundation Models, iOS 26+) to classify unlabelled fields, kept optional and offline.
- Separate multi-page PDF export (revision 7 exports the inspected composite image as one PDF page).
