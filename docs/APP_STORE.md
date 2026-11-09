# Releasing MaskCopy

## MaskCopy name (build 6)

The owner approved MaskCopy. The GitHub repository and installed product/display name have been renamed. Keep bundle ID `com.feiyangtang.Maske`, app ID 6832059753, and the current TestFlight app record. Internal project/scheme/module names remain Maske. The product is now MaskCopy.app, while the release script's archive container remains `build/appstore/Maske.xcarchive`.

App Store Connect title **MaskCopy: Safe ID Copies** was saved and confirmed in the English (U.S.) App Information page on 8 November 2026. The existing app record, bundle ID and SKU are unchanged. This changes the backend metadata; the app has not been released on the public App Store.

## Every build

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` (every upload needs a higher build number), and `MARKETING_VERSION` for a new version. Add it to `CHANGELOG.md`.
2. Check everything:
   ```bash
   scripts/check.sh
   ```
3. Build, sign and upload:
   ```bash
   scripts/appstore.sh upload
   ```
   Apple processes the build in 5–15 minutes. It then goes automatically to the internal TestFlight group **TangSpark**.

Build 4 upload completed at 01:49 Amsterdam time on 8 November. Xcode reported `Upload succeeded` and `Uploaded package is processing`. This confirms transfer, not Ready to Test or installation availability. Its signed archive was verified as 0.1.0 (4), with a 1024 px AppIcon and no specimen images or UI test bundle. The app icon artwork was not changed.

Build 5 upload completed at 11:54 Amsterdam time on 8 November. Xcode reported `Upload succeeded`, `Uploaded package is processing` and `EXPORT SUCCEEDED`. Ready to Test / installation availability has not been confirmed. Its actual archive is 0.1.0 (5), bundle com.feiyangtang.Maske; strict signature verification passed, the compiled AppIcon includes a 1024 × 1024 image, and no fixtures or test bundles are embedded. Icon artwork is unchanged. App/UI, accessibility-size and keyboard verification is recorded in [AUDIT.md](AUDIT.md).

Build 6 upload completed at 13:26 Amsterdam time on 8 November. Xcode reported `Upload succeeded`, `Uploaded package is processing` and `EXPORT SUCCEEDED`. The signed archive identifies itself as MaskCopy, version 0.1.0 (6), bundle `com.feiyangtang.Maske`; strict signature verification passed, the compiled AppIcon includes 1024 × 1024 pixels, and no fixtures or test bundles are embedded. Icon artwork is unchanged. Subsequent browser verification confirmed that build 6 is assigned to the TangSpark internal group and the existing tester is shown as having installed 0.1.0 (6) on 8 November. This confirms internal installation availability; no external beta or App Store submission was made.

Build 7 upload completed at 16:46 Amsterdam time on 8 November. Xcode reported `Upload succeeded`, `Uploaded package is processing` and `EXPORT SUCCEEDED`; the browser independently showed version 0.1.0, build 7, Processing in Build Uploads. Installation availability is not yet confirmed. The actual archive is MaskCopy 0.1.0 (7), bundle `com.feiyangtang.Maske`, with strict signature verification passed, unchanged 1024 × 1024 AppIcon, and no fixtures or test bundles. Core, synthetic, gesture, PDF-save/share and compact accessibility verification is recorded in AUDIT.md. The App Store Connect name remains MaskCopy: Safe ID Copies.

Build 8 upload completed at 17:36 Amsterdam time on 8 November. Xcode reported `Upload succeeded`, `Uploaded package is processing` and `EXPORT SUCCEEDED`. Browser verification independently confirmed version 0.1.0, build 8, Processing. Installation availability is not yet confirmed. The archive is MaskCopy 0.1.0 (8), bundle `com.feiyangtang.Maske`; strict signature verification passed, the compiled AppIcon includes the unchanged 1024 × 1024 artwork, and no fixtures or test bundles are embedded. Native Liquid Glass alignment and appearance/export checks are recorded in AUDIT.md and DESIGN.md.

Build 9 upload completed at 17:48 Amsterdam time on 8 November. Xcode reported `Upload succeeded`, `Uploaded package is processing` and `EXPORT SUCCEEDED`. Browser verification independently confirmed version 0.1.0, build 9, Processing. Installation availability is not yet confirmed. Strict signature verification passed for MaskCopy 0.1.0 (9), bundle `com.feiyangtang.Maske`. This build intentionally replaces the old icon with the owner-selected C card/lock artwork, with a more prominent lock. The compiled Assets.car contains a 1024 × 1024 AppIcon; the embedded optimized 120 px PNG was decoded and visually verified to show the selected lock. No fixture images or test bundles are embedded. Two focused Simulator UI journeys passed without runtime warnings; see AUDIT.md.

Build 10 upload completed at 18:11 Amsterdam time on 8 November. Xcode reported `Upload succeeded`, `Uploaded package is processing` and `EXPORT SUCCEEDED`. The subsequent browser session had expired, so installation availability could not be independently confirmed. Strict signature verification passed for MaskCopy 0.1.0 (10), bundle `com.feiyangtang.Maske`; the selected-C 1024 × 1024 AppIcon is unchanged and no test resources are embedded. This revision reorganizes Documents by type/country and replaces the decorated watermark with uniform translucent lettering. Core 18/18 and final normal/compact document and save/share checks passed; see AUDIT.md.



Run `scripts/ui-check.sh` on a booted Simulator for the editor/export regression before a UI release. The build 4 checks are recorded in KNOWN_ISSUES; the iOS Simulator still misses the photo and MRZ of one synthetic Chinese passport turned 90°, while the Mac passes that case.

## One-time setup

| What | Status |
|---|---|
| Distribution signing | Cloud-managed by Xcode (team X933P26489) |
| Bundle ID `com.feiyangtang.Maske` | Registered by the first archive (`-allowProvisioningUpdates`) |
| App record | Created 7 November 2026, Apple ID 6832059753 |
| TestFlight | Internal group TangSpark, automatic distribution on, Feiyang Tang added |
| Builds uploaded | 0.1.0 (1) and (2), 7 November; (3), (4), (5), (6), (7), (8), (9) and (10), 8 November 2026 |
| Developer Program License Agreement | An update was waiting for the account holder to accept (needed before App Review; not needed for internal TestFlight) |
| Export compliance | `ITSAppUsesNonExemptEncryption` is NO in `project.yml` |

## App Store Connect

Prepared 9 November 2026. Fill these into App Store Connect (English (U.S.) version page and App Information). Character limits are in brackets.

| Field | Value |
|---|---|
| Platform | iOS (iPhone only) |
| Name | MaskCopy: Safe ID Copies (saved) |
| Bundle ID | `com.feiyangtang.Maske` |
| SKU | `maske-ios` |
| Primary language | English (U.S.) |
| Primary category | Utilities |
| Secondary category | Productivity |
| Price | Free |
| Availability | All countries and regions except China mainland, which needs an ICP filing number (as for Kvikkshot and Rydd) |
| Age rating | 4+ (answer "None" / "No" to every questionnaire item) |
| App Privacy | Data Not Collected |
| Export compliance | Already answered by `ITSAppUsesNonExemptEncryption = NO` |
| Content rights | No third-party content |
| Copyright | 2026 TangSpark |
| Privacy Policy URL | https://github.com/tangfy97/MaskCopy/blob/main/PRIVACY.md |
| Support URL | https://github.com/tangfy97/MaskCopy/blob/main/SUPPORT.md |
| Marketing URL (optional) | https://github.com/tangfy97/MaskCopy |
| Sign-in required | No |

### Version number (decide before submitting)

The App Store version in App Store Connect must equal the build's `CFBundleShortVersionString`. Builds 1–12 are **0.1.0**, while App Store Connect created the version page as **1.0**. Either rename the App Store version to 0.1.0, or (recommended for a public release) set `MARKETING_VERSION: "1.0.0"` and `CURRENT_PROJECT_VERSION: "13"` in `project.yml`, run `scripts/check.sh`, then `scripts/appstore.sh upload`, and select build 13.

### English (U.S.)

**Name** (30): MaskCopy: Safe ID Copies

**Subtitle** (30): Hide ID numbers before sharing

**Promotional text** (170):
Share a copy of your passport, ID card or driving licence with the numbers, photo and machine-readable zone covered. Everything stays on your iPhone.

**Keywords** (100):
passport,identity card,driving licence,redact,watermark,privacy,residence permit,document,scan,BSN

(No app or brand names: App Review guideline 2.3.7. Words already in the name and subtitle are indexed anyway.)

**Description** (4000):

Landlords, employers, hotels and agencies often ask for a copy of your ID. Most of them don't need your personal number, document number, photo or the machine-readable zone. MaskCopy makes a copy with those parts covered, marked with who it's for, and never sends your document anywhere.

FOUND AND COVERED
• Scan with the camera, or pick a photo or a PDF of up to four pages
• MaskCopy straightens the document and suggests what to cover: personal and document numbers, the machine-readable zone, the card access number, addresses, barcodes and the photo
• Personal numbers are recognised by their check digits, for example BSN, fødselsnummer, personnummer, PESEL, codice fiscale, NRIC, MyKad and Chinese resident ID numbers

YOU DECIDE
• Every suggestion is a box you can see before anything is shared
• Turn a kind on or off, drag a box to move it, tap it to zoom in and adjust its corners, or add your own
• Recognition varies by document version and photo, so check every box before you share

A COPY FOR ONE RECIPIENT
• The recipient, the purpose and the date are written across the document, so the copy can't be passed on as yours somewhere else
• Covered parts are painted over, never blurred
• Save or share as JPG or PDF, without location or camera details

PRIVATE BY DESIGN
• Everything happens on your iPhone with Apple's on-device text and image recognition
• No account, no analytics, no tracking, no uploads
• Nothing is kept: the document is forgotten when you finish
• Open source, so anyone can check

Passports, national ID cards, residence permits and driving licences from 27 countries are recognised field by field: the Netherlands, Germany, France, the United Kingdom, Italy, Spain, Norway, Sweden, Denmark, Finland, Belgium, Poland, Ireland, Switzerland, Austria, Portugal, the United States, Canada, Australia, New Zealand, China, Hong Kong, Taiwan, Japan, South Korea, Singapore and Malaysia. Passports from other countries still have their machine-readable zone found.

MaskCopy is free. Made by TangSpark.

**What's New**: First release.

### English (U.K.)

Same as English (U.S.); the copy already uses British spelling ("licence"). Add the localization only if the listing should appear separately in the UK storefront.

### Screenshots

6.9-inch iPhone, 1320 × 2868, opaque PNG, in [appstore/screenshots/en](appstore/screenshots/en). Upload in order 1–5. App Store Connect scales them for smaller iPhones. They show synthetic documents only (made-up people from `maske fixtures`).

| File | Headline |
|---|---|
| 1-hide.png | Share your ID, not all of it |
| 2-copy.png | A copy for one recipient |
| 3-watermark.png | Say who it's for |
| 4-home.png | Scan, or pick a photo or PDF |
| 5-documents.png | Passports, ID cards, permits, licences |

#### Remaking the screenshots

1. Boot the iPhone 18 Pro Max Simulator and override the status bar: `xcrun simctl status_bar <id> override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4`.
2. `scripts/build.sh`, install, and open a synthetic document cropped to the card (the Simulator cannot remove the table): `sips -c <h-180> <w-180> --cropOffset 90 90 Fixtures/synthetic/passport-nor.png --out passport-nor-doc.png`, then launch with `-MaskeFixture /abs/path/passport-nor-doc.png`.
3. Capture each screen with `xcrun simctl io <id> screenshot`, then compose: `swift scripts/storeshot.swift <capture.png> docs/appstore/screenshots/en/<n>.png "<headline>" "<subline>"`.

## Notes for App Review

> MaskCopy makes a copy of an identity document (passport, ID card, residence permit or driving licence) with sensitive parts covered, for sharing with a landlord, employer or hotel. All recognition runs on the device with Apple's Vision framework. The app has no networking code, no account, no analytics and no in-app purchases, and it keeps nothing after the user finishes.
>
> To try it without a real document, use the attached synthetic sample images (made-up people): save one to Photos and choose Photos on the first screen, or show it on another screen and tap Scan. MaskCopy straightens the document and covers the passport number, personal number, photo and machine-readable zone. Tap a box to adjust it, then Continue, enter a recipient (for example "Hotel Nord"), tap Preview copy, and Save or Share as JPG or PDF.
>
> The camera is used only while scanning (VisionKit document camera). Photos are chosen with the system picker, so no photo library permission is requested. The information button on the first screen lists the supported documents.

Attach in App Review Information: [appstore/review/passport-sample.png](appstore/review/passport-sample.png) and [appstore/review/licence-sample.png](appstore/review/licence-sample.png) (synthetic).

## Build 11 release

Build 11 upload completed at 09:08 Amsterdam time on 9 November 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Uploaded package is processing. Ready to Test, tester assignment and installation availability have not been independently confirmed. The archive and exported IPA passed strict signature verification as MaskCopy 0.1.0 (11), with the stable bundle ID, selected-C 1024 px icon, compiled native launch storyboard and no test resources. Core 21/21, optimized app 14/14 and final normal/compact interaction checks passed; performance limits and the owner-deferred physical-device checks are recorded in AUDIT.


## Build 12 release

Build 12 upload completed at 11:09 Amsterdam time on 9 November 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Uploaded package is processing. TestFlight Ready to Test and installation availability are not independently confirmed. Strict archive/IPA signatures, stable bundle identity, 0.1.0 (12), unchanged 1024 px selected-C icon, native LaunchScreen and absence of test/specimen resources were verified. The clean development-signed Release build 12 was installed on the connected iPhone after testing; that is separate from TestFlight installation confirmation.

This update fixes the separately observed Chinese licence address miss. Portrait geometry is unchanged at the owner’s explicit request. Core 23/23 and 43/43 synthetic documents passed. The final 17-test physical suite has 15 passes, 2 expected portrait-threshold failures and no unexpected failures/skips; the three watermark/multi-page/manual-add journeys passed. See AUDIT for raw coverage and accepted exceptions.
