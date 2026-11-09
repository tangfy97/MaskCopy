# MaskCopy: handoff for coding agents

Everything a coding agent needs to pick up this project without the conversation it came from. Read this first, then [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) and [docs/ROADMAP.md](docs/ROADMAP.md).

## What this is

The owner approved **MaskCopy** on 8 November 2026. The repository is now https://github.com/tangfy97/MaskCopy. The workspace directory, Xcode project/scheme/targets, Swift module names, CLI and debug arguments retain their legacy Maske names. The installed product is MaskCopy.app; `com.feiyangtang.Maske` must remain unchanged to preserve the existing TestFlight app. App Store Connect's English (U.S.) name was separately saved as MaskCopy: Safe ID Copies and confirmed on 8 November; see APP_STORE.

MaskCopy is a native iPhone app (SwiftUI, iOS 18+) for sharing a copy of a passport, ID card, residence permit or driving licence with the sensitive parts hidden. It is a privacy-first alternative to the Dutch government's KopieID, which only handles Dutch documents. The user scans or picks a photo, MaskCopy straightens the document, suggests masks (machine-readable zone, personal and document numbers, card access number, address, barcode, photo), the user reviews them, says who the copy is for, and saves or shares a watermarked JPG or image-only PDF.

- Owner: Feiyang Tang (TangSpark). Repository: <https://github.com/tangfy97/MaskCopy> (public, Apache 2.0).
- Status: 1.0.0 (13) uploaded on 9 Nov 2026 as the first App Store release candidate (Xcode reports Processing). The store listing is prepared in docs/APP_STORE.md but not yet entered in App Store Connect; nothing has been submitted for review (see [Releasing](#releasing)).
- The owner works in Chinese and English; replies to them in Chinese are welcome, code and docs are in English.

## Non-negotiable rules

1. **Never commit, upload, attach or paste a real person's identity document**, masked or not. Test with the synthetic documents (`maske fixtures`) and official specimens kept in `Fixtures/specimens/`, which is git-ignored because those images are not ours to publish.
2. **The app stays offline.** No networking code, analytics, crash reporting, accounts or third-party code. All recognition is Apple's Vision framework on the device. If something changes what MaskCopy keeps or shares, update [PRIVACY.md](PRIVACY.md) in the same change.
3. **Masks must cover exactly what needs covering: nothing left visible, nothing extra.** The owner was explicit about this ("完美覆盖，不多不少"). When the two conflict, leaving a sensitive character visible is worse than covering a little extra.
4. **Masks are painted into the pixels**, never blurred or pixelated (both can be reversed). The shared file has no metadata.
5. `project.yml` is the source of truth for the Xcode project. Edit it, then `xcodegen generate`. Never hand-edit `Maske.xcodeproj`.
6. Follow the TangSpark house standards (from the owner's other apps in `~/Documents`, e.g. Rydd, Kvikkshot, Glimt, Spolo): the standard doc set (README, CHANGELOG, PRIVACY, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, LICENSE, NOTICE), XcodeGen, `scripts/`, plain English docs, standard system controls, no custom styling beyond `Theme.swift`.
7. Work step by step. The owner prefers a working prototype now and documented problems over fixing everything at once: record open problems in [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) rather than leaving them in a conversation.
8. Make the UI self-explanatory. The owner strongly dislikes explanation paragraphs: use direct manipulation, familiar controls and short labels; keep instructional text to the minimum.

## Repository map

```
project.yml                 XcodeGen spec for the iOS app (bundle com.feiyangtang.Maske)
Package.swift               Swift package: MaskeCore library, `maske` CLI, MaskeCoreTests
Sources/MaskeCore/          The engine, shared by the app and the CLI (compiled into the app target directly)
  Analyzer.swift            Entry point: analyze(photo:) → straighten → rules → merged findings
  Rectifier.swift           Finds the document outline, orientation, perspective correction; VisionRunner
  Portraits.swift           Photo frames, borderless bounds, small portraits and security windows
  InkFit.swift              Fits a text box to its ink (angle, edges, label/value cut); Luma image buffer
  Geometry.swift            Quad (four corners, normalized, origin top-left) and Homography
  MRZ.swift                 ICAO 9303 TD1/TD2/TD3 + ISO 18013 licence line reader with check digits
  NumberPatterns.swift      ~45 national number formats (regex + check), strong vs country-gated
  Checksums.swift           The check-digit algorithms
  Labels.swift              Field labels in many languages, numbered licence field codes
  Countries.swift           Country table, supported list (27), country/document keywords
  Text.swift                TextLine (Vision line + corners), MappedText (folded/compacted text with index map)
  Model.swift               Finding (kind, rect, quad, isOn), PageAnalysis, DocumentKind
  Renderer.swift            The shared copy: masks painted as polygons, watermark, JPG/image-only PDF without metadata
Sources/MaskeApp/           SwiftUI app: Home, Review (PageCanvas, MaskShape), Share (watermark), Supported list
Sources/maske/              CLI: fixtures, eval, analyze, review, warp, angles, ocr (see below)
  Fixtures.swift            43 synthetic documents drawn on a "table", with exact ink bounds per field
  Warp.swift                Photo-like copies (tilt, rotation, 90°, 180°, steep) and overlays
Tests/MaskeCoreTests/       Check digits with published examples, ICAO specimen MRZs
scripts/                    build.sh, check.sh, device.sh, appstore.sh, icon.swift, fetch_specimens.py,
                            prado_receiver.py, prado_collect.js
Design/AppIcon-1024.png     Rendered by scripts/icon.swift
docs/                       DEVELOPMENT (engine), KNOWN_ISSUES, ROADMAP, DECISIONS, SPECIMENS, APP_STORE, user-journey (Chinese)
Fixtures/                   Generated and downloaded test images; git-ignored (only the generator is committed)
```

## Build, run, test

Needs Xcode 26+ (developed on Xcode 27.2, Swift 6.4, Swift 5 language mode) and XcodeGen (`brew install xcodegen`).

```sh
scripts/check.sh                 # unit tests + regenerate the 43 synthetic documents + evaluate them
scripts/ui-check.sh              # session, editor, keyboard and sharing checks on a booted Simulator
scripts/build.sh                 # app for the iOS Simulator → build/MaskCopy.app
scripts/device.sh                # signed build installed and opened on a connected iPhone (Developer Mode on)
scripts/appstore.sh upload       # archive, sign and upload to App Store Connect / TestFlight
```

The CLI (`swift build`, then `.build/debug/maske …`):

| Command | Purpose |
|---|---|
| `maske fixtures Fixtures/synthetic` | Draw the synthetic documents and `expected.json` (ink bounds of every field to hide or keep) |
| `maske eval Fixtures/synthetic` | Coverage (≥98% of a field's ink under a mask), kept fields (≤10% covered), precision (share of each mask on its field); writes masked copies and green/red overlays to `Fixtures/synthetic/out` |
| `maske analyze <image>` | What the engine finds on one photo; `MASKE_DEBUG=1` prints how every mask was made |
| `maske review <dir> <out>` | Mask every image in a folder, for looking through by eye; `report.txt` with one line per image |
| `maske warp <dir> <out>` then `maske angles <out>` | Do masks land in the same place on tilted, turned copies? Writes overlays |
| `maske ocr <image>` | Debug: Vision text recognition on the straightened image, in memory vs via PNG |

Build 4 checks (8 Nov 2026): 14 unit tests; 43/43 synthetic documents, 121/121 sensitive fields at ≥98% coverage, 96/96 kept, mean precision 0.96 (worst 0.75). On 24 selected angle fixtures the Mac covered 84/84 fields and preserved 63/63; the Simulator still missed the photo and MRZ on the 90° Chinese passport (81/84). Seven annotated official specimens passed 28/28 sensitive regions and 15/15 preserved regions. These checks do not establish pixel-perfect masking on every photograph. See KNOWN_ISSUES.

The superseded build 5 interface used: native controls, flat source/input rows, little explanation text and adaptive vertical layouts for accessibility sizes. Build 6 replaces that flow with Home → Hide → Watermark → Share and native zoom/corner controls; docs/DESIGN.md is the current design direction. Session work is guarded by a generation ID; page edits invalidate revision-bound previews. Watermark typing is local to that screen and does not render pixels. `prepareCopy` renders off-main once, caches by document/field/mask revision and guards cancellation. Preview and Share use the same CGImage. Only explicit Save or Share writes a temporary JPG/PDF. Vision cancellation is now best-effort through a task-local request registry; work that finishes late cannot publish into a newer session. See docs/AUDIT.md for rendered coverage and device checks still needed.

Revision 7 removes the three-stage tracker and illustrative Home. The source chooser uses three coherent icons and short labels, with press feedback and no looping decoration. Whole-mask movement is available in Review and the native editor through `Quad.translated(by:)`, preserving shape while clamping at page edges. The final preview exposes JPG/PDF, Save and Share; Close replaces Done. PDF embeds the same flattened JPEG on one image page with no Info dictionary, text or annotation layer. Saved destination copies belong to the user; temporary attempt directories are cleared separately. See docs/DESIGN.md for the current design.

Revision 8 adopts native Liquid Glass on iOS 26+: glass/glassProminent styles, grouped effects, safeAreaBar scroll edges and one regular-glass editor surface, with iOS 18–25 standard-control fallbacks. Home uses a native leading title; content titles collapse according to the system, and the editor keeps normal Cancel/Save navigation. Keep glass off document pixels, masks and watermark. Theme.swift owns the availability wrappers and increased-contrast palette. Current research and validation limits are in DESIGN/AUDIT.

Revision 9: the owner selected privacy-logo C with a more prominent lock and requested no brand mark or text on Home. Production AppIcon is generated by scripts/icon.swift; the three studies remain in Design/Studies/2026-11-08. Home shows only task controls; functional screens have compact inline titles. Theme.swift draws the selected mark only on the privacy cover. See DESIGN/AUDIT for verification.

Revision 10 changes Documents to four full document-type rows with country-profile navigation. Theme.swift owns their accessibility layout. The watermark is now uniform translucent red text at 30 degrees using multiply over document printing and a clipped light pass over opaque masks; remove the old rules/large recipient. Build 10 placement was fixed; revision 11 adds manual per-page placement, without OCR collision avoidance. Renderer’s black-print/opacity/PDF regressions and UI evidence are in AUDIT. PRIVACY reflects the exported treatment.

Revision 11 implements the three-skill audit fixes: PDFs/scans up to four pages import in full; longer sources require native thumbnail selection (up to four) with source order preserved. ImportSource serializes PDF/scanner access and retains its security scope; it writes no unredacted temporary files. ImageIO downsamples image imports with orientation applied. Add box opens a centred editor draft directly (native page menu for multiple pages); Save commits and Cancel discards. WatermarkPositionView supports per-page dragging, semantic move actions and Reset using cached glyph sprites. Positions invalidate page revisions; final copy rendering remains off-main and stale copies cannot be exported. Export writes and asynchronous cleanup share one serial queue. Active Vision requests receive best-effort cancel(), with generation guards retained. A native LaunchScreen matches Home. Physical-device testing was explicitly deferred by the owner; see AUDIT for final Simulator evidence.

9 November physical follow-up: Developer Mode and device registration succeeded. Optimized Release passed 16 app/Home/launch checks; relaunch mean 306 ms and four-page render mean 39.6 ms. Four synthetic documents passed 12 recognition trials (228 ms/page mean), subject to incomplete portrait annotation limits. An optimized DEBUG fixture run passed the native editor journey; a 10.708-second partial Animation Hitches recording had two 16.67 ms events. Watermark gestures and the seven official specimen device checks remain unverified because the phone auto-locked. See AUDIT. DeviceRecognitionTests intentionally skip in the Simulator; their optional fixture resources are test-target-only. Physical UI fixtures resolve relative to Library/Caches under DEBUG and must be removed after testing. No new TestFlight binary was uploaded for these test-only changes.

Build 12 follow-up: the owner accepted current portrait extents; **do not enlarge them to force 98% annotation coverage**. Four measured official-specimen portrait regions use explicit expected failures plus baseline floors; annotations/global threshold are unchanged. Watermark/multi-page/manual-add physical journeys passed 3/3. A separate Chinese licence address leak (OCR “住址” above “Adtre北京”) was fixed using constrained bilingual association and existing ink fitting; two physical trials now cover its address fully while preserving dates. Final device suite: 15 passed + 2 expected portrait failures, no unexpected failures or skips. Core 23/23 and 43-document synthetic checks passed. Raw coverage and remaining scanner/printed-specimen/frame-pacing limits are in AUDIT.

App launch arguments for the Simulator (Debug builds only, `DebugLaunch` in `MaskeApp.swift`):

```sh
xcrun simctl launch booted com.feiyangtang.Maske -MaskeFixture /abs/path/front.png,/abs/path/back.png \
  -MaskeRecipient "Hotel Nord" -MaskePurpose "Check-in" -MaskeStep share   # or -MaskeStep supported
```

## How the engine works (short)

Full description: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

1. **Straighten** (`Rectifier.straighten`): quick `.fast` text reads of a ≤1300 px copy in all four orientations pick the orientation (readable MRZ lines score +80) and give the text positions. `VNDetectDocumentSegmentationRequest` (fallback `VNDetectRectanglesRequest`) outlines are accepted only if ≥80% of that text lies inside and the aspect is < 2.1. Then `CIPerspectiveCorrection` with corners reordered for the quarter turns. Output ≤2600 px. `DocumentImage.corners` maps back to the source (used by the CLI to compare with expected boxes).
2. **Read** (`Analyzer.recognize`): accurate text recognition (automatic language; a second pass in zh/ja/ko when the page has CJK), faces, barcodes, each request separately so one failing cannot lose the others. Re-reads up to twice if the result has fewer than 80% of the quick read's lines.
3. **Find**: MRZ (bottom-most run of `[A-Z0-9<]` lines) → kind and issuing country; else keywords; else a strong number pattern. Then number patterns (country-gated unless distinctive), values the MRZ names elsewhere on the page, labelled values (same line, right, or below), numbered licence fields (EU/ISO 18013/AAMVA: 4d, 5, 8), unlabelled codes, the 6-digit CAN on European ID cards, street addresses, faces → portrait (snapped to the portrait's rectangle when found), ICAO portrait zone measured from the MRZ when no face, barcodes.
4. **Fit** (`InkFit`): every text mask is measured on the pixels (Otsu threshold; ink is the minority class), levelled to the text's own angle (Theil–Sen line through per-column ink tops/bottoms, iterated), extended through ink Vision's box cut (gaps up to 0.35× height) and shrunk to the first/last ink, margin max(3 px, 12% of ink height). Values beside a label: `addPart` predicts where the label ends from character widths (CJK 1.0, Latin caps/digits 0.65, space 0.3 of the height) and cuts at the nearest ink gap (≥0.15×h), accepting it only if the value's width matches within 20%; then re-measures the value alone.
5. **Merge**: overlapping findings of one kind keep the most exactly measured shape (cut > ink-fitted > estimate), else the larger.

## Gotchas learned the hard way

- **iOS Simulator has no Neural Engine.** Vision's face, barcode and document-outline requests return nothing there (text works on the CPU via `VisionRunner`). So the Simulator never crops the table away and never finds faces or barcodes. Verify those on a device or on the Mac (`maske`).
- **Vision text recognition is not deterministic across processes and time.** The same straightened image read 17 lines in a standalone script and 13 inside `maske` (both MRZ lines lost). Not caused by the image, request settings, revision, earlier requests, Core Image or the deployment target. See issue 1 in KNOWN_ISSUES.
- **Heavy load on the Mac makes Vision crawl or fail** (`CRImageReaderError.unknownError` after minutes). Games and some system cleaners compete for the GPU/Neural Engine. Check `uptime` before trusting a slow or failing test run.
- `CTLineDraw` advances the text position: measure `CTLineGetImageBounds` before drawing (bit us in the fixture generator).
- In Helvetica-like fonts the gap after a "1" is as wide as a word space; never split values on small gaps.
- Vision's line boxes can lean a few degrees off the actual text; `InkFit` levels them. Mixed CJK/Latin lines bias baseline estimates (CJK glyphs sit lower), so the value part is re-measured alone.
- `VNRecognizedText.boundingBox(for:)` may return word-level boxes, and OCR may merge a label and its value into one word.
- Vision returns Cyrillic look-alikes in Latin numbers ("А123456(3)"); `MappedText(latinize:)` maps them back.
- Germany's MRZ issuing state is `D<<`; Kosovo's is `RKS`.

## Releasing

Details: [docs/APP_STORE.md](docs/APP_STORE.md).

- Team X933P26489 (Feiyang Tang). Distribution signing is cloud-managed by Xcode (`-allowProvisioningUpdates`); local development certificate "Apple Development: Feiyang Tang (F72B32W28N)".
- App Store Connect: app "MaskCopy: Safe ID Copies" (saved and confirmed on 8 Nov 2026), Apple ID 6832059753, SKU `maske-ios`, bundle `com.feiyangtang.Maske`, primary language English (U.S.).
- TestFlight: internal group **TangSpark**, automatic distribution on, the owner added. Builds: 0.1.0 (1) and (2) on 7 Nov 2026; build (3) uploaded 8 Nov 2026 (specimen, MRZ and portrait fixes). Build (4), with photo/window/editor/watermark changes, uploaded successfully at 01:49 Amsterdam time on 8 Nov. Apple reported Processing; Ready to Test / installation availability was not confirmed. The signed archive contains the unchanged 1024 px AppIcon.
- Build (5), the native interface/session revision, uploaded successfully at 11:54 Amsterdam time on 8 Nov. Xcode reported Upload succeeded and Processing; Ready to Test is not confirmed. The signed 0.1.0 (5) archive passed signature verification, contains the unchanged 1024 px AppIcon and contains no fixture images or test bundles. Verification is recorded in docs/AUDIT.md.
- Build (6), the MaskCopy workflow/native editor/watermark revision, uploaded successfully at 13:26 Amsterdam time on 8 Nov. Apple initially reported Upload succeeded and Processing; subsequent browser verification confirmed assignment to TangSpark and the existing tester’s installed 0.1.0 (6). Signature, stable bundle ID, build number and 1024 px AppIcon were verified. Core checks passed 15/15; app/UI verification is in docs/AUDIT.md.
- Build (7), the minimal source chooser, custom icon/feedback, whole-mask dragging and JPG/PDF export revision, uploaded successfully at 16:46 Amsterdam time on 8 Nov. Upload succeeded / EXPORT SUCCEEDED, and the browser independently showed build 0.1.0 (7) Processing. Signature, stable bundle ID, version, unchanged 1024 px AppIcon and absence of test images/bundles were verified. Core 17/17 and 43/43 synthetic documents passed; UI/export recovery checks are in AUDIT. Build 7 installation is not yet confirmed.
- Build (8), the native Liquid Glass controls/navigation revision, uploaded successfully at 17:36 Amsterdam time on 8 Nov. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing; browser verification independently confirmed build 8 Processing. Strict signature, stable bundle ID, version 0.1.0 (8), unchanged 1024 px AppIcon and absence of test images/bundles were verified. Core 17/17, 43/43 synthetic documents, the light 17-check suite and final compact/export regressions passed. Installation availability is not yet confirmed. See AUDIT and DESIGN.
- Build (9), the selected C privacy icon and logo-free Home revision, uploaded at 17:48 Amsterdam time on 8 Nov. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing; browser verification independently confirmed build 9 Processing. Strict signature, stable bundle ID, version 0.1.0 (9), full-size 1024 px AppIcon and absence of test images/bundles were verified; the actual compiled small icon was decoded and visually checked for the larger lock. Two focused Home/workflow UI journeys passed without runtime warnings. Installation availability is not yet confirmed.
- Build (10), the explicit document types and translucent watermark revision, uploaded at 18:11 Amsterdam time on 8 Nov. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing. Strict signature, stable bundle identity, 0.1.0 (10), unchanged 1024 px selected-C icon and no test resources were verified. Core 18/18 passed; normal and compact document browsing and actual PDF/JPG save/share checks are in AUDIT. Installation availability is not yet confirmed.
- Build (11), the three-skill audit fixes, uploaded successfully at 09:08 Amsterdam time on 9 Nov 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing. Strict archive/IPA signatures, stable identity, 0.1.0 (11), unchanged selected-C 1024 px icon, native LaunchScreen and absence of test resources were verified. Core 21/21 and optimized app 14/14 passed, alongside final normal/compact interaction checks. The owner deferred physical-device testing; Ready to Test and installation availability are unconfirmed. See AUDIT for measurement limits.
- Build (12), the bilingual address recovery, uploaded successfully at 11:09 Amsterdam time on 9 Nov 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing. Strict archive/IPA signatures, stable identity, unchanged 1024 px selected-C icon and no test/specimen resources were verified. Portrait bounds are unchanged at the owner’s request. Core 23/23 and 43/43 synthetic documents passed; the physical 17-test suite has 15 passes + 2 expected accepted-portrait failures, no unexpected failures/skips. Watermark/multi-page/manual-add physical journeys passed 3/3. A clean development-signed Release build 12 was installed on the iPhone; TestFlight readiness/installation is unconfirmed.
- Build (13), version **1.0.0**, the first App Store release candidate: the same app as build 12, renumbered so it can be selected for the App Store version page. Uploaded successfully at 13:08 Amsterdam time on 9 Nov 2026 (Upload succeeded / EXPORT SUCCEEDED, Processing). Archive verified: MaskCopy 1.0.0 (13), bundle `com.feiyangtang.Maske`, team X933P26489, strict signature, 1024 px AppIcon, no test or specimen resources, 1.3 MB. Core 23/23 and 43/43 synthetic documents passed before upload. Not yet submitted for review.
- Every upload needs a higher `CURRENT_PROJECT_VERSION` in `project.yml`. `ITSAppUsesNonExemptEncryption` is NO.
- The Apple Developer Program License Agreement update was pending acceptance by the account holder (needed before App Review). Do not accept agreements on the owner's behalf.
- The owner's site tang-spark.no is a personal studio site, not this product's website; don't add pages there unless asked.

## Where to go next

[docs/ROADMAP.md](docs/ROADMAP.md) has the ordered list. The most valuable next step is running `maske review` over the PRADO specimens of the 27 supported countries and turning each mistake into a fix plus a synthetic fixture. Then on-device testing (barcodes, faces, speed).

Decisions and the reasons for them: [docs/DECISIONS.md](docs/DECISIONS.md). Where test images come from and how to collect more: [docs/SPECIMENS.md](docs/SPECIMENS.md).
