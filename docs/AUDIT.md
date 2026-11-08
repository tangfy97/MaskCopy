# Interface and usability verification

## Unreleased: compact brand header and privacy-logo studies

The owner rejected the oversized brand title and requested privacy-focused logo alternatives. Home now has a 40-point leading card mark, with an accessible MaskCopy name and no decorative glass-button background. Review, Watermark, Your copy and Documents use compact native inline titles. Theme’s mark now includes the original artwork’s lower visible line. The installed AppIcon and build number remain unchanged; three native vector-path studies are proposals in Design/Studies/2026-11-08.

On the iPhone 18 Pro Simulator, `CompactTitles.xcresult` passed Home/Documents/search and review→watermark→copy→zoom→Close (2/2). Visual inspection found that the decorative logo initially inherited a misleading glass background; this was explicitly hidden. `FinalHeader.xcresult` then passed the affected Home/Documents/search journey (1/1). Both result bundles report no runtime warnings. Final Home and compact review captures were inspected and kept under build/BrandStudy. These focused light-mode checks do not establish dark/maximum-text layout, VoiceOver navigation or real-device performance for this change. The logo comparison was inspected at large and small sizes; B’s lock detail is intentionally documented as weaker when small.

## Build 8: researched Liquid Glass alignment

Research consulted Apple's WWDC26 Design guide, current Materials HIG, Adopting Liquid Glass, Applying Liquid Glass to custom views, the WWDC25 new-design-system transcript and the installed iOS 27.2 SDK interfaces. The detailed sources and decisions are in `docs/plans/2026-11-08-liquid-glass-design.md`. Key interpretation: glass is a functional layer, and stronger leading typography applies to key situations rather than every control/title.

Changes: native glass/glassProminent source and action buttons, GlassEffectContainer grouping, native safeAreaBar/scroll-edge treatment without the old opaque footer backing, a regular-glass editor control surface, native leading Home title and adaptive content titles, consistent content-group radii and increased-contrast theme variants. Older iOS retains guarded standard-control fallbacks. Mask geometry, recognition and exported pixels are unchanged.

- `scripts/check.sh`: 17 core checks and 43/43 synthetic documents passed; 121/121 sensitive fields at the existing ≥98% threshold, 96/96 kept, mean precision 0.96, worst 0.75.
- `Light.xcresult`: 17 app/unit/UI checks passed, no runtime warnings. Coverage includes the new source controls, direct mask movement, zoom/corners, keyboard positioning, actual PDF save, JPG save cancellation, sharing and recovery. Rendered Home, final copy and editor captures were inspected under `build/Revision8/light/`; the controls use native glass rather than a custom blur/shadow replica.
- Compact dark/increased-contrast/maximum accessibility text: the initial run passed three journeys but failed the share-dismissal wait. Visual inspection also found insufficient contrast on pale prominent buttons and a wrapped Reset label. Dedicated on-accent foreground colors, vertically stacked accessibility editor actions, an explicit full-height accessibility share presentation and a readiness wait address the observed issues. `CompactFinal.xcresult` passed all four affected journeys, with no runtime warnings; final Home, copy and editor captures were visually inspected under `build/Revision8/compact-ax/`. This is functional evidence, not a claim that the first failure had only one cause.
- `FinalExport.xcresult`: both final normal-size keyboard/share recovery and PDF-save/share journeys passed, with no runtime warnings. The inspected final screenshots show the native resizable share panel, clear JPG/PDF choices and readable Save/Share controls.
- Reduced Transparency/Reduce Motion system-setting interaction could not be exercised through desktop control: the tool could not resolve the Simulator app. Native glass supplies its platform accessibility adaptation; this source-level fact is not a completed visual setting test. Manual device checks remain open. The iOS 18 fallback is availability-gated and compiled, but no iOS 18 runtime is installed for a visual compatibility check.
- Device frame pacing is unmeasured. Host load reached approximately 467 during verification; do not infer performance from the loaded simulator or claim a launch/GPU improvement. Native glass styles own touch response, related effects are grouped and no looping/decorative animation was added.

Build 8 upload completed at 17:36 Amsterdam time on 8 November. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing; the browser independently confirmed build 8 Processing. The signed archive passed strict verification, identifies itself as MaskCopy 0.1.0 (8) with the stable bundle ID, retains the unchanged 1024 px AppIcon and contains no fixture images or test bundles. Installation availability is not yet confirmed.

## Build 7: fewer words, direct movement, explicit export

The owner rejected revision 6's Home, tracker, watermark and final Done action. Revision 7 replaces Home with three source actions and a coherent custom icon set in Theme.swift, removes the three-stage tracker everywhere, uses a compact lower purpose stamp, supports whole-mask dragging, and exposes JPG/PDF plus Save/Share. The final exit is named Close. The intent is more breathing room and direct operation; this is not a claim that the owner has accepted the aesthetics.

Evidence is generated/synthetic only, stored locally under `build/Revision7/`. Light and compact dark/maximum-text captures were visually inspected. The homepage has no introductory heading, cards or explanation paragraph. The watermark was checked with short/long English recipients and Chinese input, plus a rendered PDF. Its fixed placement can still overlap some document layouts; it is not content-aware positioning.

- `scripts/check.sh`: 17 core tests, 43/43 synthetic documents, 121/121 sensitive fields at the existing ≥98% threshold, 96/96 kept, mean precision 0.96 and worst 0.75. Recognition rules are unchanged. This does not prove perfect redaction on all photographs.
- `FinalLight.xcresult`: 17 app/unit/UI checks passed, including off-main rendering/cache/cancellation, actual PDF saving, JPG save cancellation, PDF/JPG sharing, direct Review mask movement and native editor body/corner gestures. `FinalDetails.xcresult` then passed the two affected icon/save-feedback journeys after design refinements.
- Compact iPhone SE, dark, maximum accessibility text: Home/documents, actual PDF save/share and editor zoom/body movement/Save/Cancel passed in `CompactAX.xcresult`. The keyboard/share journey exposed a dismissal problem: the native share panel could remain over the final screen. Explicit completion callbacks now clear presentation state. Both affected keyboard/share and PDF-save paths passed in `CompactFinal.xcresult`, with no runtime warnings.
- PDF was independently opened by Core Graphics, PDFKit and Poppler. It has one image page, zero extracted characters, annotations and document attributes, no form/JavaScript/metadata stream, and correct orientation. Its embedded JPEG matches image export, with no source document or mask layers. The watermark/redaction test verifies output is independent of the original pixels under opaque masks. Translating multi-page text can vary Core Text antialiasing by two luma levels; opacity equality remains exact.
- No physical iPhone was connected (`xctrace list devices`). Native transforms and cached images avoid bitmap relayout during zoom; gesture changes update only geometry, and rendering/encoding runs off-main. Scan-button press animation is short and interruptible, respects Reduce Motion and adds no artificial delay. Haptics are limited to pickup and save completion. These source-level properties and functional tests do not establish device frame pacing or universal smoothness. Manual VoiceOver, physical scanner capture and on-device Instruments remain open.

The first save-picker test assumed Cancel remained on a nested Files screen; the observed picker provides Save there and Cancel at Browse. The regression now completes an actual save and navigates back explicitly for cancellation. Runtime warning arrays were empty in the final result bundles. `ReleaseGate.xcresult` then passed both final normal-size save/share journeys and responsive launch measurement, with no runtime warnings. Five debug-simulator startup samples averaged 3.46 s (range 3.41–3.57 s). Host load was still high (observed approximately 74–145), and only the main simulator was running during the launch samples. These timings are not a real-device budget, do not measure animation frame pacing, and are not comparable enough to claim a launch-speed improvement. Release status is in APP_STORE.md.

The signed archive was verified as MaskCopy 0.1.0 (7), with stable bundle ID, unchanged 1024 px AppIcon and no test data/bundles. Upload completed at 16:46 Amsterdam time on 8 November. Xcode reported Upload succeeded / EXPORT SUCCEEDED, and the browser independently showed build 7 Processing. Installation availability is not yet confirmed.

## Build 6: MaskCopy

The owner rejected build 5's homepage, flow, motion and pale masks. The archived audit below describes checks performed on that build, not acceptance by the owner. Build 6 replaces the design. Current rules are in DESIGN.md.

### Research and scope

Read RvIG's KopieID FAQ, official App Store screenshots and the current MaskID description from Apple's public lookup endpoint (app 6790398619). KopieID uses one primary start action, visible field switches, opaque dark masks and an in-document diagonal watermark. MaskID already provides OCR suggestions, manual masks, watermarks, flattened exports, metadata checks, a vault and optional cloud features. Shared capabilities are not claimed as unique. The proposed distinction is a focused multi-country ID workflow and document-specific geometry/precise review, whose remaining limits are in KNOWN_ISSUES. No competitor code or image is bundled.

Sources: https://www.rvig.nl/veelgestelde-vragen-kopieid-app , https://apps.apple.com/nl/app/kopieid/id932970330 , https://apps.apple.com/ca/app/maskid-protect-what-you-share/id6790398619 . Motion reference: https://developer.apple.com/videos/play/wwdc2024/10145/ .

### Implemented

- Home uses a deliberate document motif, one scan action and secondary Photos/Files, replacing the flat launch list. Visible native switches replace the hidden mask menu. Hide → Watermark → Share makes each decision explicit with short labels.
- Watermark text stays local to its screen; typing triggers no bitmap work. The final image is rendered off-main before navigation, reused while document/mask/input revisions match, and invalidated on edits. Cancellation and generation checks guard late completion. Share and inspection use the same CGImage, and only Share creates a JPEG.
- Opaque charcoal replaces the pale fill. Every page includes recipient, purpose and date in one diagonal block, dark over the document and light over redactions. The removable footer and outlined lettering are gone. The watermark never reduces redaction opacity.
- Native UIScrollView replaces layout-driven zoom in the editor and final copy. The bitmap is installed once; pinch, double-tap and momentum use native transforms. Four corner targets keep a 44-point on-screen size at every zoom. The editor grows from its source document through the iOS 18 native zoom transition. Camera decoding starts after dismissal. The ready screen retains its image during dismissal and has its own privacy shield.
- Large-text review exposed real issues: giant source symbols, broken progress labels, horizontally compressed dates and overly tall actions. Source choices and dates now stack, progress shows the active stage/count, and labels shorten without shrinking the selected text size.

### Verified evidence

Generated images only; no real identity document was collected or committed. Final light captures are in `build/Redesign6/light/`, dark maximum-text captures in `compact-ax/`, and the system photo-import journey in `import/`. Build 5 comparison captures remain in `build/UXReview/after-light/`.

- Core: 15 tests passed after the final renderer changes, including a regression proving that a mask cannot paint another page or its gap. The 43-document synthetic check passed 121/121 sensitive fields at the existing ≥98% threshold and 96/96 kept fields, mean precision 0.96, worst 0.75. Recognition code is unchanged; this does not establish complete redaction on all photographs.
- Final normal-size suite: 14 app/UI checks passed, with the guarded photo import intentionally skipped on the personal/main simulator. The launch test was run separately. All final result bundles report no runtime warnings.
- Compact iPhone SE, dark appearance, maximum accessibility text: Home/search, keyboard/system sharing and editor pinch/zoom/Save/Cancel passed. The first import test failed because the system picker's first-use notice hid the photo and its confirmation is now Done. After adapting the test to the observed picker, the isolated normal-size photo import passed end to end. The default suite skips this test unless explicitly enabled on a synthetic-only library.
- Corner testing includes double-tap, pinch, zoomed scrolling/dragging, 44-point targets, Save and Cancel. Cache/cancellation tests verify off-main rendering, reuse, edit invalidation and no late publication after finishing.

### Performance measurements and limits

Measurements are descriptive, not a smoothness guarantee. No physical iPhone was attached. Host load was unusually high (observed load averages approximately 119–284), with simulator first-use services and other active processes. No unrelated app was stopped.

- Same generated-pixel Mac workload, ten measured renders after warm-up: build 5 mean 1.58 ms for one page / 5.71 ms for four; final dual-tone watermark mean 1.87 / 8.65 ms. The richer watermark costs more rendering work. The architectural change removes it from typing and transitions rather than claiming a faster renderer.
- iPhone 18 Pro Simulator debug four-page render, five XCTest samples: mean 66.4 ms, maximum 67.4 ms. Peak process footprint mean 91.9 MB, maximum 94.5 MB; measured per-run physical growth 0–16.4 kB. These are test-process measurements, not a whole-session memory bound.
- Responsive launch with only the main simulator running, five XCTest samples: mean 3.71 s, range 3.63–3.80 s. This loaded debug-simulator result is not an acceptable real-device launch claim or evidence of improvement; measure an optimized device build before setting a release budget.
- Animation Hitches recording was attempted and returned “Hitches is not supported on this platform.” No frame-rate or dropped-frame result is claimed. The editor journey passed again during a motion recording (`build/Redesign6/editor-motion.mp4`); this is visual evidence, not a frame-pacing benchmark.

Still needed: optimized real-iPhone launch/recognition latency, continuous gesture/frame pacing under Instruments, physical scanner capture, manual VoiceOver/Switch Control/Reduce Motion and photographed printed-specimen tests. Functional tests and visual inspection do not establish those results.

### Naming and release

The owner chose MaskCopy after rejecting MaskID and CopyVeil. GitHub is now https://github.com/tangfy97/MaskCopy . The product/display name is MaskCopy; bundle ID and internal project/modules stay stable for updates. The App Store Connect English (U.S.) title was saved as MaskCopy: Safe ID Copies on 8 November and the page showed Saved. TestFlight also confirmed the existing internal tester had installed 0.1.0 (6). This proves installation, not device performance or acceptance of the interface. Release status is recorded in APP_STORE.md.

---

# Archived build 5 audit

8 November 2026. Baseline: c2d3ec3, build 4. Scope: Home, import/loading/recovery, Review, mask controls, corner editor, Share, copy inspector, system share sheet and supported documents. Test documents are generated fixtures only. The masking engine and icon artwork are unchanged.

## Evidence and coverage

Baseline screenshots came from the actual app on iPhone 18 Pro, iOS 27 Simulator. They showed a large branded landing layout, a prominent block of switches below the document, shadowed preview cards, repeated field chrome and a long introductory paragraph in Documents. Screenshots and test result bundles are kept locally under build and /tmp/maske-ux; they are not specimen images or committed assets.

The target direction is documented in DESIGN.md. The offline design search's generic hero/testimonial and neumorphic suggestions did not fit this utility and were rejected. The useful guidance was functional hierarchy, restrained surfaces, native controls, honest progress and recoverable actions. No third-party UI library, font or analytics service is added.

## Findings and changes

### P1: late work could modify a newer or cancelled session

Static evidence: Session.start previously launched recognition without a cancellation or generation check. Delayed results could overwrite pages after the user left or started another document. Import work had the same risk.

Changed: explicit preparing/reading states, background decoding, cancelable tasks and generation checks. Returning Home clears the session. Current Vision work can finish offscreen; later pages are skipped. App regressions deliberately finish an old read/import late and verify that it cannot reopen or replace the current session.

### P1: an outdated preview could remain shareable while details changed

Static evidence: Share previously retained the previous file while an asynchronous replacement was being prepared. Detached results had no final cancellation/revision check. Typing also repeatedly wrote temporary files.

Changed: previews stay in memory and are tied to document, mask and input revisions. Share is enabled only for the current rendered inputs. An explicit Share action creates the JPEG; separate attempts own separate directories. Cancellation discards only its own result. Abandoned temporary copies are cleared on the next session. Regressions cover preview file absence, independent export ownership and startup cleanup; the UI journey checks actual keyboard input and system-sheet presentation.

### P2: decoration and repeated controls competed with the document

Observed in the baseline Home, Review and Share captures. The old homepage had a display-sized brand, mark and slogan. Review repeated its controls in a large switch card. Custom field borders and preview shadows added weight without another task.

Changed: flat source choices, system typography, a cool neutral background and one grey-blue accent. Review uses a smaller context line and native Masks menu. Share uses two flat labelled input rows and one primary action. The image opens a zoomable copy inspector. Explanation paragraphs are omitted.

### P2: small masks and newly drawn rectangles were hard to adjust

Changed: nearest-edge selection within 22 points improves access to short text masks without enlarging the exported polygon. Drawing a mask opens the four-corner editor immediately. Bulk toggles remain available in the native menu. UI regressions exercise menu selection, drawing, scrolling, zoomed corner dragging, Save and Cancel.

### P2: import and failure states lacked a clear recovery path

Changed: photo/file decoding runs away from the main actor, opening and reading states provide immediate feedback, and Cancel remains available during work. Unreadable input returns to a native alert and usable Home. The scanner forwards images into the same import pipeline. Camera hardware and actual iCloud-provider delays still require device checks.

### P2: duplicated accessibility labels and weak secondary text

Observed during the keyboard test: native labelled fields were announced as “Recipient, Recipient”. Removed redundant accessibility labels and kept stable test identifiers. Shared semantic colours replace washed-out custom secondary text.

Calculated token contrasts on their actual semantic backgrounds: light primary 13.33:1, light muted 5.17:1, light action 6.93:1; dark primary 15.46:1, dark muted 8.49:1, dark action 10.09:1. These are selected colour-pair measurements, not a claim of complete accessibility conformance. Native alert dismissal was also adjusted after the first run exposed a state-publication runtime warning; the subsequent run had none.

### P3: supported-document lookup required unnecessary reading and scrolling

Changed: removed the introductory claim of exhaustive field-by-field verification, kept the country/document list and added native country search. Recognition limitations remain in KNOWN_ISSUES rather than a paragraph on the lookup screen.

### P2: maximum accessibility text size compressed horizontal layouts

Observed on a 375 × 667 point iPhone SE Simulator, dark appearance, accessibility-extra-extra-extra-large: document types broke into individual letters, field labels hyphenated beside compressed values, decorative symbols consumed text width and a fixed footer reduced the scrollable source area. The action bar also competed with the keyboard for editing space.

Changed: stack document types, Review context and labelled inputs vertically at accessibility sizes; omit source-row symbols at those sizes and keep zoom symbols compact. Source choices and their footer share a scrollable area. Hide the share action while a field is focused and restore it after keyboard Done; Next moves to Purpose. Scroll the focused row into view on focus changes and after the keyboard opens, respecting Reduce Motion. The keyboard test exercises that actual navigation and checks the field is fully above the keyboard. These changes preserve the user's selected text size.

## Verification status

Baseline captures are kept at `build/UXReview/before/{home,review,share,documents}.png`; final captures use `build/UXReview/after-light/` and `after-compact-ax/`. All are generated documents, kept locally and excluded from Git. The Home, Review, Share, Documents, editor and copy inspector captures were visually inspected. In particular, the final compact keyboard capture shows the Purpose label and complete focused input above the keyboard.

- `scripts/check.sh`: 14 core tests passed; 43/43 synthetic documents, 121/121 sensitive fields at the existing ≥98% coverage threshold, 96/96 preserved fields. Mean mask precision 0.96, worst 0.75. Recognition code is unchanged in this release; these numbers do not establish complete masking on real photos.
- iPhone 18 Pro, iOS 27 Simulator, light appearance and normal text: 11/11 app/UI tests passed in `/tmp/maske-ux/Release5Light.xcresult` (five app-state/file tests and six UI tests). After the final focus-scroll fix, both affected Share journeys passed again in `FocusLight.xcresult`.
- iPhone SE (3rd generation), 375 × 667 points, iOS 27 Simulator, dark appearance and maximum accessibility text: 4/4 selected journeys passed in `Release5CompactAX.xcresult` (Home/search, Review/preview, keyboard/system sharing and corner editing). The final keyboard visibility assertion and share journey passed again in `FocusCompactAX.xcresult` after the focus-scroll fix. Normal-size compact Home/Share were also checked earlier.
- These final result bundles contain no runtime warnings. `git diff --check` passed. Earlier failures exposed actual large-text layout issues and inadequate test assumptions about virtualised list rows and asynchronous share-sheet dismissal; they were corrected and rerun.
- The signed release archive passed strict signature verification as 0.1.0 (5), includes the unchanged 1024 × 1024 AppIcon, and contains no fixture images or test bundles. App Store Connect accepted the upload at 11:54 Amsterdam time on 8 November and reported Processing. Ready to Test remains unconfirmed.

Still unverified: physical camera capture, real-device frame pacing and recognition time, manual VoiceOver use, Switch Control and Full Keyboard Access. Reduce Motion is respected by the drawing-mode transition and standard navigation remains native; a system-setting device check is still needed. No business-impact, frame-rate or full-conformance score is claimed.
