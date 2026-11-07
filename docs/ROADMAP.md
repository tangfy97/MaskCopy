# Roadmap

In order. Each step should end with its check in `scripts/check.sh` (or a note of how it was verified), an update to [KNOWN_ISSUES.md](KNOWN_ISSUES.md), and a CHANGELOG entry. The owner prefers small, working steps over large rewrites.

## Now: make the prototype right on real documents

1. **Feedback from TestFlight build 2.** The owner is testing on an iPhone. Each wrong mask they report (country, document, which field, angle) becomes a synthetic fixture and a fix. Never ask for or store the photo itself.
2. **Review the PRADO specimens of the 27 supported countries.** `maske review Fixtures/specimens/prado <out>` (filter to the supported ISO3 codes), look at every masked copy, list mistakes in KNOWN_ISSUES, fix them rule by rule. Expect recognition problems from the 600 px size; consider upscaling 2× before analysis for the test only.
3. **Angle test on specimens.** `maske warp` + `maske angles` on the same set; compare with the synthetic numbers.
4. **Text recognition missing lines** (KNOWN_ISSUES 1): reproduce on a device, then add a targeted MRZ pass (bottom third, `en-US`) when a passport-shaped page has no MRZ.
5. **On-device checks:** PDF417 on US/Canadian licences, real faces and the portrait mask, speed per page (target: under 2 seconds on a recent iPhone).

## Next: make it a 1.0

6. **Localization** to the house standard: English, English (UK), Simplified Chinese, Traditional Chinese (String Catalog). Consider Dutch and Norwegian for the main audience.
7. **Accessibility pass:** VoiceOver for mask toggles (labels exist), Dynamic Type on Review and Share.
8. **App Store listing:** screenshots (made from synthetic documents), description, privacy "Data Not Collected", age 4+, category Utilities, support and privacy URLs, review notes (in [APP_STORE.md](APP_STORE.md)). The account holder must accept the updated Developer Program License Agreement first.
9. **Website pages** only if the owner asks (tang-spark.no is a personal studio site).

## Later

- More supported countries, one at a time, each with a specimen review and fixtures.
- Signatures (no detection yet), QR code contents (masked, not read).
- iPad layout; Mac (Catalyst or native) using the same MaskeCore.
- Optional on-device language model (Apple Foundation Models, iOS 26+) to classify unlabelled fields, kept optional and offline.
- Export as PDF in addition to JPEG.
