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

### Version number

Decided 9 November 2026: the public release is **1.0.0**. Build 13 is 1.0.0 (builds 1–12 are 0.1.0). The App Store version in App Store Connect must equal the build's `CFBundleShortVersionString`: set the version page to **1.0.0** (it was created as 1.0) and select build 13.

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

### English (U.S.), version 1.1.0

Decided 19 November 2026: the name moves from ID copies to document copies, because MaskCopy Pro adds payslips, bank statements and bills. The free app still copies identity documents only.

**Name** (30): MaskCopy: Safe Document Copies

**Subtitle** (30): Hide numbers before you share

**Promotional text** (170):
Share a copy of your passport, ID card, payslip or bank statement with the numbers, photo and account details covered. Everything stays on your iPhone.

**Keywords** (100):
passport,id card,payslip,bank statement,redact,watermark,privacy,residence permit,licence,scan

**Description** (4000):

Landlords, employers, banks and agencies ask for copies of your documents. Most of them don't need your personal number, document number, account number or photo. MaskCopy makes a copy with those parts covered, marked with who it's for, and never sends your document anywhere.

FOUND AND COVERED
• Scan with the camera, or pick a photo or a PDF of up to four pages (twelve with Pro)
• MaskCopy straightens the document and suggests what to cover: personal and document numbers, the machine-readable zone, the card access number, addresses, barcodes and the photo
• Personal numbers are recognised by their check digits, for example BSN, fødselsnummer, personnummer, PESEL, codice fiscale, NRIC, MyKad, Emirates ID and Chinese resident ID numbers

YOU DECIDE
• Every suggestion is a box you can see before anything is shared
• Turn a kind on or off, drag a box to move it, tap it to zoom in and adjust its corners, or add your own
• Recognition varies by document version and photo, so check every box before you share

A COPY FOR ONE RECIPIENT
• The recipient, the purpose and the date are written across the document, so the copy can't be passed on as yours somewhere else
• Covered parts are painted over, never blurred
• Save or share as JPG or PDF, without location or camera details

MASKCOPY PRO
• Payslips, bank statements and bills, with account numbers (IBAN, card, sort code and account number), tax and social security numbers and addresses covered
• On bank statements, transactions are hidden and salary stays readable
• Several documents in one PDF, with a checklist for renting, a job or a visa
• Up to 12 pages per document
• A list of who has your copy, kept on your iPhone, with a reminder to ask for deletion
• One purchase, shared with your family

PRIVATE BY DESIGN
• Everything happens on your iPhone with Apple's on-device text and image recognition
• No account, no analytics, no tracking, no uploads
• Nothing is kept: the document is forgotten when you finish
• Open source, so anyone can check

Passports, national ID cards, residence permits and driving licences from 30 countries are recognised field by field: the Netherlands, Germany, France, the United Kingdom, Italy, Spain, Norway, Sweden, Denmark, Finland, Belgium, Poland, Ireland, Switzerland, Austria, Portugal, the United States, Canada, Australia, New Zealand, China, Hong Kong, Taiwan, Japan, South Korea, Singapore, Malaysia, Saudi Arabia, Egypt and the United Arab Emirates. Passports from other countries still have their machine-readable zone found.

MaskCopy is free for identity documents. MaskCopy Pro is an optional in-app purchase. Made by TangSpark.

**What's New**:
• MaskCopy Pro: payslips and bank statements, several documents in one PDF, up to 12 pages, and a list of who has your copy
• Saudi Arabia, Egypt and the United Arab Emirates
• More documents from the United States and Canada
• A clearer Documents page and a short tour

**Screenshots (1.1.0)**: six 1206 × 2622 opaque PNGs in [appstore/screenshots/en](appstore/screenshots/en), replacing the 1.0.0 set. Captured on the iPhone 18 Pro Simulator by `StoreShotUITests` in the private repository (`TEST_RUNNER_MASKCOPY_STORESHOTS=<folder> xcodebuild test … -only-testing:MaskeUITests/StoreShotUITests`, status bar overridden to 9:41), then `scripts/storeshot.swift` for the headline. Screens 1–2 use the Dutch 2021 passport specimen (RvIG), shown unaltered; the Simulator's masks on it are complete level rectangles with no hand edits. Screens 3–4 use synthetic bank statements and payslips.

| File | Headline | Subline |
|---|---|---|
| 1-hide.png | Share your ID, not all of it | Numbers, photo and MRZ are found and covered. You check every box. |
| 2-copy.png | A copy for one recipient | Who it's for, why and when, written across it. |
| 3-statement.png | Bank statements too | Transactions hidden, salary kept. With MaskCopy Pro. |
| 4-pack.png | One PDF for the whole application | Passport, payslips and statements, with a checklist. Pro. |
| 5-pro.png | MaskCopy Pro | One purchase, shared with your family. |
| 6-documents.png | 30 countries | Passports, ID cards, residence permits and driving licences. |

**In-app purchase**: add MaskCopy Pro to the version page before submitting (the first in-app purchase must go with a version). Its App Store Connect details are in the private repository.

### English (U.K.)

Same as English (U.S.); the copy already uses British spelling ("licence"). Add the localization only if the listing should appear separately in the UK storefront.

### Screenshots

"iPhone with Dynamic Island (medium display)", 1206 × 2622, opaque PNG (1320 × 2868 was rejected), in [appstore/screenshots/en](appstore/screenshots/en). Upload in order 1–5. Screens 1 and 2 show official public specimens from Wikimedia Commons, not real people's documents: [Norwegian ID card 2021](https://commons.wikimedia.org/wiki/File:New_Norwegian_ID_Card_(2021)_(Front).png) (public domain, Government of Norway) and the data page of the [Dutch passport 2014](https://commons.wikimedia.org/wiki/File:Dutch_passport_specimen_issued_9_March_2014.jpg) (CC0, RvIG). The [Norwegian passport 2020](https://commons.wikimedia.org/wiki/File:Norwegian_Passport_Specimen.jpg) (public domain) is also usable, but its secondary portrait is not masked (KNOWN_ISSUES) and the Simulator's face-less portrait estimate overlaps the MRZ. Keep the images in `Fixtures/specimens/store/` (git-ignored).

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
> To try it without a real document, use the attached image, the official specimen of the Dutch passport published by the Dutch government (not a real person): save it to Photos and choose Photos on the first screen, or show it on another screen and tap Scan. MaskCopy straightens the document and covers the document number, both photos and the machine-readable zone. Tap a box to adjust it, then Continue, enter a recipient (for example "Hotel Nord"), tap Preview copy, and Save or Share as JPG or PDF.
>
> The camera is used only while scanning (VisionKit document camera). Photos are chosen with the system picker, so no photo library permission is requested. The information button on the first screen lists the supported documents.

Attach in App Review Information: [appstore/review/review-sample.png](appstore/review/review-sample.png), the data page of the [Dutch passport specimen](https://commons.wikimedia.org/wiki/File:Dutch_passport_specimen_issued_9_March_2014.jpg) (CC0, RvIG). One document per image, so the reviewer can pick it directly.

## Build 11 release

Build 11 upload completed at 09:08 Amsterdam time on 9 November 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Uploaded package is processing. Ready to Test, tester assignment and installation availability have not been independently confirmed. The archive and exported IPA passed strict signature verification as MaskCopy 0.1.0 (11), with the stable bundle ID, selected-C 1024 px icon, compiled native launch storyboard and no test resources. Core 21/21, optimized app 14/14 and final normal/compact interaction checks passed; performance limits and the owner-deferred physical-device checks are recorded in AUDIT.


## Build 12 release

Build 12 upload completed at 11:09 Amsterdam time on 9 November 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Uploaded package is processing. TestFlight Ready to Test and installation availability are not independently confirmed. Strict archive/IPA signatures, stable bundle identity, 0.1.0 (12), unchanged 1024 px selected-C icon, native LaunchScreen and absence of test/specimen resources were verified. The clean development-signed Release build 12 was installed on the connected iPhone after testing; that is separate from TestFlight installation confirmation.

This update fixes the separately observed Chinese licence address miss. Portrait geometry is unchanged at the owner’s explicit request. Core 23/23 and 43/43 synthetic documents passed. The final 17-test physical suite has 15 passes, 2 expected portrait-threshold failures and no unexpected failures/skips; the three watermark/multi-page/manual-add journeys passed. See AUDIT for raw coverage and accepted exceptions.


## Build 13 release (1.0.0)

Build 13 upload completed at 13:08 Amsterdam time on 9 November 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Uploaded package is processing. It is build 12's app renumbered as **1.0.0** for the public release; no app code changed. Verified before and after upload: core 23/23 and 43/43 synthetic documents (121/121 sensitive fields, 96/96 kept); archive MaskCopy 1.0.0 (13), bundle `com.feiyangtang.Maske`, team X933P26489, strict signature, 1024 px AppIcon in Assets.car, no test or specimen resources, 1.3 MB. Ready to Test and App Store submission are not yet confirmed or done.

App Store Connect, 9 November 2026: the 1.0.0 version page is complete and saved. It has the listing text above, the five 1206 × 2622 screenshots, build 13 (Ready to Submit), Sign-in required off, the review notes and `review-sample.png`, the App Review contact (the owner's standard contact for all TangSpark apps), and the release set to *Automatically release this version* (the owner's choice). App Information, Data Not Collected and Pricing and Availability are saved. The optional custom product-page header asset is empty.

**Submitted for review** at 14:32 Amsterdam time on 9 November 2026, after the owner accepted the updated agreement and confirmed. App Store Connect shows 1.0.0 (13) *Waiting for Review* (Apple says up to 48 hours). Release is automatic: once approved, it goes live.

## Build 14 release (1.1.0)

Build 14 upload completed at 18:22 Amsterdam time on 17 November 2026 (Upload succeeded / EXPORT SUCCEEDED, Processing), for TestFlight. 1.0.0 is on the App Store, so this is version **1.1.0**: Saudi Arabia and Egypt, more US documents, the first-run/update tour and the dark-mode action-text fix. Archive: MaskCopy 1.1.0 (14), bundle `com.feiyangtang.Maske`, strict signature, no test or specimen resources, 1.4 MB. Checks before upload: core 24/24, 54/54 synthetic documents (144/144 hidden, 134/134 kept), Simulator UI 30/30 with 4 device-only skips, seeded photo import passed. Physical-device tests were not run. Ready to Test is not yet confirmed. To release it, create a 1.1.0 version page, add What's New and select build 14.

## Build 15 (1.1.0)

Uploaded 18:54 Amsterdam time, 17 November 2026 (Upload succeeded / EXPORT SUCCEEDED, Processing). The animated tour replaces build 14's drawings; the app is otherwise the same. Archive: 1.1.0 (15), strict signature, 1.9 MB, with the tour's three open-licence specimens (sources in NOTICE) and the globe data. Select build 15, not 14, when the 1.1.0 version page is made.

## 1.1.0 version page (19 November 2026)

Entered in App Store Connect: version 1.1.0 created (Prepare for Submission) with the 1.1.0 promotional text, description, keywords and What's New above; the six new screenshots (the 1.0.0 set was removed from this version only; it stays in the Asset Library); build 20; new App Review notes covering MaskCopy Pro and the attached Dutch 2021 passport specimen; automatic release kept from 1.0.0. App Information: name "MaskCopy: Safe Document Copies" and subtitle "Hide numbers before you share" saved (released with the next version). The MaskCopy Pro in-app purchase has the new Pro sheet as its review screenshot and updated review notes, and was added to the draft submission. At the owner's request, 1.1.0 (20) was added to the same draft and the draft (1.1.0 plus MaskCopy Pro) was submitted for App Review at 18:50 Amsterdam time on 19 Nov 2026: "2 Items Submitted", 1.1.0 Waiting for Review, automatic release on approval. App Store Connect showed no blocking errors; its notices (age-rating questions on location sharing and dating, due 15 Jan 2027; China mainland security assessment and AIGC declaration, due 31 Jan 2027). At the owner's request both China mainland items were answered in App Compliance on 19 Nov 2026 and show Active: AIGC services offered in China mainland, No (on-device Vision text recognition and painted masks only, no generated or synthetic content); features requiring a security assessment, No (no networking, messaging or content distribution). The two new age-rating questions were answered the same day at the owner's request: Shared Location, No; Dating and Relationships, No. All other answers unchanged; the calculated rating stays 4+ (Not Applicable override). The version page then showed no notices, and 1.1.0 stayed Waiting for Review.

## 1.1.0 rejection and resubmission (22 November 2026)

App Review rejected 1.1.0 (20) under Guideline 2.1(b): on an iPad Air 11-inch (M3) the reviewer could not locate the MaskCopy Pro in-app purchase. The product was requested once at launch and a failed request left the buy button spinning. Build 22 retries, reloads when a Pro screen opens, offers Try Again, makes the Home entry a filled "Unlock Pro" button and shows a Free/Pro comparison with the purchase pinned below.

In App Store Connect: build 22 selected for 1.1.0; review notes now start with "TO FIND THE IN-APP PURCHASE" and three steps; a reply with the same steps was sent in the submission's messages; 1.1.0 (22) and MaskCopy Pro were resubmitted (Waiting for Review). Not changed: the in-app purchase's review screenshot (build 20 sheet) and the App Store screenshots (5-pro.png shows the older sheet).
