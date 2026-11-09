# Interface and usability verification

## 9 November: first physical-iPhone validation

The owner enabled Developer Mode and resumed physical testing. Xcode first needed automatic device registration (`-allowProvisioningDeviceRegistration`) before it could update the development profiles. Tests used iPhone 18 Pro, iOS 27.2, wired, with Xcode 27.2. No personal documents or Photos library were accessed. Local evidence: /tmp/maskcopy-device11; do not commit trace/test-image artifacts.

- **Canonical optimized Release:** InitialRegistered.xcresult passed **16/16**, no skips or runtime warnings: 14 app tests, native Home/Documents navigation and responsive launch. Five responsive **relaunches** averaged **306.48 ms**, range **269.55–323.85 ms**. This is not an uncached, post-reboot cold-launch measurement. The four-independent-page render averaged **39.60 ms**, range **39.35–40.01 ms**; test-process peak physical memory **156.99 MB decimal**, range **156.98–157.01 MB**. The render workload excludes OCR/import; these are not whole-session memory or leak bounds.
- **Full recognition pipeline:** RecognitionMeasured.xcresult passed **1/1**, no skips or runtime warnings. Four generated samples (Dutch licence, Norwegian ID front, Chinese ID front and Chinese passport), three trials each: **228.16 ms/page mean**, **110.48–507.63 ms**. The first Dutch trial took 507.63 ms; the two repeats took approximately 123/121 ms. Timing begins after source image decoding and includes straightening, OCR, faces/barcodes and rule/geometry analysis; it excludes import/export/render. **48/48** annotated sensitive-region checks met the existing ≥98% sampled coverage threshold and **27/27** preserved-region checks stayed below 10% coverage. Type/country matched in all 12 trials. Initial Recognition.xcresult was skipped because its resources were missing; it is explicitly excluded from passed counts.
- **Limits of these accuracy checks:** the synthetic Norwegian ID's large portrait is an unannotated silhouette; its passing numbers do not validate that photo's complete rectangle. Generated samples and sampled annotation coverage do not establish pixel-perfect masking on real photographs, small windows or all document versions. The seven official specimen checks are compiled into the test harness but have not yet run on the iPhone.
- **Physical mask editor:** EditorGestures.xcresult passed **1/1**, no runtime warnings, using an optimized Debug (`-O`) build solely to enable the generated-fixture hook. The journey includes whole-mask/corner movement, pinch/double-tap/slider zoom, constant-size corner targets, Save/Cancel persistence and final-copy preparation. It uses one generated passport in the dedicated app cache, not Photos.
- **Measured animation sample:** Animation Hitches attached to the tested MaskCopy PID for **10.708 s**, 09:58:53–09:59:04 Amsterdam time; target exit ended recording before its requested 35-second limit. The trace contains **450 frame lifetimes** and **two app hitch events of 16.6695 ms each**. It covers only the final portion of the editing journey, not every gesture or a sustained frame-rate test. Exported CPU samples near those events primarily show QuartzCore/UIKit/SwiftUI work, with partially unresolved symbols; no specific application-code hotspot was established and no speculative runtime optimization was applied. Idle/adaptive-refresh frames must not be divided into the trace duration to claim a fixed FPS.
- **Remaining physical checks:** the phone auto-locked before WatermarkGestures.xcresult could start. Its three watermark/multi-page/manual-add journeys are unverified on device. The owner was asked to unlock again; after waiting, the pending run was interrupted rather than reported as a test pass. The watermark trace attempt found no running process and is excluded. Dedicated generated-cache cleanup could not be confirmed while the device was unavailable; retry cleanup when resuming. Official specimens, physical scanner capture, printed/photographed specimens, manual VoiceOver and continuous gesture/frame pacing remain open.

The repeatable harness packages generated samples and the locally downloaded official specimens in **MaskeAppTests only**. No input pixels are committed. A clean production Release build was inspected and contains no fixture/specimen images, expected manifests or test bundles. The only app-source change is relative-path handling inside the existing DEBUG-only fixture launcher; production behavior/build 11 is unchanged. Device helper signing now supports first-time registration. The physical follow-up supersedes the earlier blanket statement that no device measurement was available, without closing the remaining validation work.

## Build 11: completing the three-skill findings

9 November 2026. The owner authorized implementation, then explicitly deferred physical-device testing. Preserve the logo-free Home and selected-C icon; do not imply that functional tests establish frame pacing or recognition accuracy on all photographs.

### Changes and acceptance

- **Silent truncation fixed:** up to four PDF/scanner pages import in full. Longer sources open an explicit thumbnail selector, bounded to four selected pages; selection retains source order. Cancel imports nothing. Source access is serialized, decoded pages use autorelease pools, and no unredacted temporary source files are created. Photos uses the same four-page picker limit. ImageIO applies orientation while downsampling images before full-raster allocation.
- **Semantic creation fixed:** Add box opens a centred draft in the existing accessible corner/body editor. Multi-page documents first offer a native page menu. Save commits; Cancel leaves no custom finding. Gesture-only drawing mode is removed.
- **Watermark placement fixed:** Move watermark opens per-page direct positioning with Reset and named accessibility move actions. A shared Core Text layout supplies glyph sprites and fitted bounds; dragging changes transforms only. Save updates page revisions and renders the final immutable copy off-main. Export requires the displayed CGImage to match the current Session.copy, preventing stale output during replacement. Placement remains manual, not OCR collision avoidance.
- **Responsiveness improvements:** session cleanup and export writes share a serial background I/O queue; UI dismissal never waits synchronously for file removal. Active Vision requests receive best-effort cancel(), and later requests/pages are skipped. Generation/revision checks still prevent late publication. A native launch storyboard matches Home's light/dark background. No recognition rules, telemetry or third-party code were added.
- **Rendered accessibility correction:** initial maximum-text evidence showed Page/number split across lines and truncated editing titles. Page rows now stack their thumbnail/checkmark above full-width labels. The compact picker uses Pages and the placement editor uses Watermark; Cancel/Save remain standard native controls. Normal-size labels retain their full wording. The watermark selection rectangle was tightened to the fitted text width rather than the wrapping constraint.

### Verification

All document inputs were generated, synthetic fixtures; no personal identity document was used. Result bundles and screenshot attachments remain local under /tmp/maskcopy-fixes11 and are not committed.

- Core: **21/21** passed, including active/pending Vision cancellation and completed-request isolation, per-page placement, clamping, unchanged adjacent pages/gaps, opaque redaction, black-print preservation and image-only PDF checks.
- Full synthetic check: **43/43** document kinds and countries; **121/121** sensitive regions meet the existing ≥98% sampled coverage threshold, **96/96** kept fields preserved, mean precision **0.96**, worst **0.75**. These thresholds do not establish pixel-perfect coverage on arbitrary photographs.
- Optimized app tests: **14/14** passed in ReleaseFinal.xcresult, no runtime warnings. Includes three-page PDF completeness; five-page explicit selection, selected order and invalid-index/duplicate rejection; ImageIO orientation/downsampling; session cancellation, off-main/cache reuse, watermark-position invalidation and ordered cleanup/export ownership.
- Normal light Simulator: Journeys2.xcresult passed **10/10** (Home/Documents, keyboard, recovery, Add Save/Cancel, native mask editor movement/zoom, watermark movement Save/Cancel/Reset, PDF save, JPG cancel and system share). FinalLight.xcresult passed **4/4** after fitting the watermark frame: long CJK lettering, actual selected-page handoff, independent page targeting and placement persistence. No runtime warnings.
- Compact iPhone SE, iOS 27 Simulator, dark appearance and maximum accessibility text: Compact.xcresult passed **6/6**, CompactFinal.xcresult **3/3** for final fitted lettering/CJK and selected-page import, then CompactVerified.xcresult **2/2** after correcting the observed row/title layout. All report no runtime warnings. Final page-limit, selected-import and placement screenshots were visually inspected; normal CJK lettering and final output were also inspected. These checks are not manual VoiceOver or Switch Control validation.
- Archive and exported IPA: strict signatures verified; bundle com.feiyangtang.Maske, version **0.1.0 (11)**, compiled native launch storyboard, selected-C **1024×1024** icon and no fixture/specimen/test bundles. The compiled small icon was decoded and visually checked for the prominent corner lock.

Build 11 upload completed at 09:08 Amsterdam time on 9 November 2026. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Uploaded package is processing. Ready to Test, tester assignment and installation availability have not been independently confirmed. The archive and exported IPA passed strict signature verification as MaskCopy 0.1.0 (11), with the stable bundle ID, selected-C 1024 px icon, compiled native launch storyboard and no test resources. Core 21/21, optimized app 14/14 and final normal/compact interaction checks passed; performance limits and the owner-deferred physical-device checks are recorded in AUDIT.

### Performance evidence and remaining work

Five optimized responsive Simulator relaunches, with only the main Simulator running: **3.714 s mean**, **3.444–4.215 s**. ReleaseLaunch.xcresult passed, no runtime warnings. The prior five-sample result was 3.807 s under a different host/time/load condition; this is not evidence of a causal improvement or an acceptable device startup budget. The native launch background matches Home; this does not resolve the measured startup time. No new usable App Launch/Hitches trace was obtained, so no main-thread hotspot or frame-rate claim is made.

The revised render workload uses **four independently drawn 2600×1600 pages**, with printed synthetic glyph blocks and opaque portrait masks, instead of four references to one unfilled raster. Five optimized samples: **78.71 ms mean**, **76.93–81.93 ms**. Test-process peak physical memory **154.94 MB decimal mean**, **151.62–157.06 MB**; per-iteration growth **0–16.384 kB**. This excludes OCR/import and does not establish a whole-session memory limit or leak freedom. The workload changed, so it is not a direct speed/memory comparison with the old 67.25 ms/92.02 MB result. Rendering remains off the main actor and does not run during watermark typing/dragging.

The connected iPhone reported Developer Mode disabled. The owner explicitly chose to proceed without real-device testing, so physical launch/recognition timing, gesture frame pacing, scanner capture, manual assistive technology and photographed printed-specimen checks remain open. Faint/coloured printing and dense-document watermark readability still require review; repositioning is not automatic collision avoidance. See KNOWN_ISSUES for recognition and uncertain-rectification limits.

## 8 November: requested three-skill audit of build 10

Installed and directly read the owner’s requested skills from their linked upstream sources: [UX Flow Auditor](https://github.com/charleswiltgen/axiom/tree/main/axiom-codex/skills/axiom-audit-ux-flow), [Apple UI Designer](https://github.com/heyman333/atelier-ui/tree/main/skills/apple-ui-designer), and [Performance Profiling](https://github.com/MengTo/Skills/tree/main/agent-skills/codex/performance-profiling). They live under the owner’s Codex skills directory, outside this app repository, and are available automatically next turn. All four native-performance references were consulted. Local source hashes are in build/SkillAudit/installed-sources.json. No third-party code was added to the app.

Scope: review/check, following the owner’s request. Production code and build number remain at the verified build 10. One temporary synthetic PDF reproduction method was added to the existing test host, run and restored byte-for-byte; it is not a shipped regression/fix. No new TestFlight build is produced by this audit.

### Journey architecture map

1. MaskCopyApp → RootView owns a single in-memory Session.
2. Home exposes scanner, PhotosPicker and Files import.
3. No deep links, widgets, notifications, accounts or networking are implemented.
4. Import decoding runs off-main; Review shows opening/reading progress and Cancel.
5. Review offers native kind switches, individual masks, drawing and the corner editor.
6. Watermark keeps draft input local, then prepares a revision-bound copy off-main.
7. Your copy exposes JPG/PDF, native Files export, system sharing and Close.
8. Documents offers type → country navigation plus a country directory/search.
9. Returning Home/Close clears the session; cancelled workers cannot publish into a newer session.

### Scan, completeness and health

Sixty-one search patterns were run separately over production app Swift files, with test/preview/build/vendor/docs sources excluded. Matched views and surrounding callbacks were read, including Root, Home, Review, Share/Ready, Importing, Session, the editor, native viewport and current theme. Raw matches/counts are local in build/SkillAudit/scan.json. Notable counts: two NavigationStacks, one navigationDestination site, two sheet sites, one fullScreenCover, two SwiftUI DragGestures in Review, six detached-work sites and no repeating timers/display links/URLSession calls. UIKit accessibilityCustomActions were checked in addition to SwiftUI accessibilityAction searches, avoiding a false accessibility finding for existing-mask movement/corners.

UX health: **ROUGH EDGES**, a qualitative skill label rather than a platform certification. There are three source-to-copy routes; multi-page limits leave PDF and scanner completeness gaps. All three asynchronous screens (Review, Watermark, Your copy) have relevant progress/error/empty-or-content handling. Five modal presentation sites have explicit native or callback exits (six modes when Save and Share are counted separately). The editor’s disabled swipe dismissal is paired with Cancel/Save. External entry-point validation is not applicable because there are no external entries. VoiceOver flow coverage has not been manually measured; the manual-add path has the concrete source gap below. Informational destinations, iPhone-only portrait scope and parent-owned camera dismissal were not reported as defects.

Unique findings: zero confirmed CRITICAL, two HIGH, one existing MEDIUM. Completeness and compound observations refer to those same findings rather than inflating the issue count.

### HIGH — silent page truncation (detected and reproduced)

Importing.swift:23 defaults PDF import to two pages; :25 truncates pageCount without returning a warning or original page count. Importing.swift:75 similarly takes only the first four scanned pages. These are two affected sites in one file. The interface says photos/PDF and provides no page-selection or truncation feedback. Session receives only the shortened array, so its reading count cannot expose the omitted pages.

An optimized iOS test created a PDF with three independently drawn pages, verified the source page count and called the actual Importing.images(fromPDF:) default. It returned two pages. PDFReproduction.xcresult passed the observation assertion (1/1), no runtime warnings. Passing here confirms the undesired truncation, not correctness. The camera limit is source-verified; physical scanner reproduction remains unavailable while the iPhone is offline.

Next release priority, affecting multi-page PDF/scans: make the limit explicit and let users select pages, or reject an oversized input before reading. Do not silently raise limits without measuring independent-image memory. Acceptance: a three-page PDF or five-page scan cannot silently produce a shorter copy. This is a high-value flow fix; no implementation estimate is claimed.

### HIGH — no accessible alternative for creating a manual mask (source-verified)

ReviewView.swift:209 appends a custom finding only in the drawing DragGesture.onEnded path. Add box only enters drawing mode. This is one affected creation path in ReviewView.swift. Existing masks already have UIKit custom actions for body movement and all four corners (DocumentViewport.swift:60, :79); those controls are not missing.

When automatic detection misses a field, creating the missing box remains gesture-dependent. This compounds the known recognition-recovery limitation. Manual VoiceOver testing has not been completed, so this is a missing semantic alternative, not a claim that all assistive-technology operation has been exercised.

Next release priority, affecting manual recovery: Add box can create a default rectangle and open the existing accessible editor immediately. Free drawing may remain optional. Acceptance: a user can create, adjust, save and export a new mask using semantic actions without a drawing gesture. No extra instruction paragraph is needed.

### MEDIUM — fixed watermark placement (existing, visually verified)

Renderer.swift:71–80 fixes every watermark at the page centre and 30 degrees. The build 10 long-recipient capture crosses the synthetic birth-date field; multiply blending keeps pure black printing unchanged before JPEG encoding but does not choose an empty region or guarantee coloured/faint text legibility. This affects the shared renderer, not a separate JPG/PDF implementation.

Backlog/next small design iteration: allow direct position adjustment with a low-cost vector preview, then render immutable export pixels off-main; content-aware placement requires carrying trustworthy text geometry. Acceptance must inspect dense fronts/backs, short/long and CJK input, final JPG/PDF and retained fields. Do not promise perfect avoidance or unremovable watermarks.

### Apple UI review

The current optimized Home was launched and its settled screenshot inspected (build/SkillAudit/home.png); its first immediate screenshot was only the transient launch screen and was not treated as a dead end. The existing build 10 Documents, Review, watermark and saved-copy captures, plus earlier unchanged editor captures, were used alongside their source. Home keeps the owner-approved no-wordmark/no-logo layout and three short source labels. Functional screens use native inline titles, native glass controls on the functional layer and standard lists/sheets. The editor has 44-point corner targets and native scroll/zoom. Accessibility document rows stack icons over full-width text. The review found no evidence warranting another broad cosmetic redesign. Manual VoiceOver, reduced visual-effects settings and oldest-supported-runtime checks remain open; this is not HIG/WCAG certification.

### Optimized performance evidence and limits

ReleaseTests.xcresult passed nine app-session tests with no runtime warnings. This includes cancelled import/read/render isolation, preview reuse/invalidation and temporary export ownership. Release configuration used ENABLE_TESTABILITY=YES for XCTest. The existing four-page rendering metric collected five samples: mean 67.25 ms, range 66.31–67.89 ms. Mean test-process peak physical memory was 92.02 MB decimal (range 89.41–93.90 MB); per-iteration changes ranged −32.768 to +16.384 kB. These measurements are not a leak test or memory bound for real sessions: the benchmark uses one unfilled 2600×1300 source image referenced four times, not four independently decoded photographs, and it does not run OCR.

ReleaseLaunch.xcresult then passed the responsive-launch check (1/1), no runtime warnings. Five optimized simulator relaunches measured 3.807 s mean, range 3.687–3.991 s, using XCTApplicationLaunchMetric(waitUntilResponsive: true). This is a slow observed simulator startup result, not an acceptable device budget or a measured cold-launch guarantee. It cannot be compared causally with the earlier differently loaded debug runs. The first immediate manual screenshot showed only the launch screen; the settled Home was subsequently inspected. Startup remains a profiling priority, alongside recognition and real-device frame pacing.

The physical iPhone was listed offline. A target-only Time Profiler recording was made on the optimized Mac CLI with a generated Norwegian passport. The 45-second recording limit ended the process before analysis completed; the trace records time-limit SIGKILL, not an application crash. Apple text-recognition model-bundle warnings occurred. Export contained 5,121 CPU sample rows, but raw stack addresses rather than attributed/symbolicated hot functions, so no hotspot optimization or device recognition-time claim is made. This evidence calls for a device reproduction and a validated symbolicated profile; it does not establish an app UI main-thread hang.

A separate 15-second App Launch recording was attempted against the optimized Simulator app. Instruments reported a missing table input and a sampling-period mismatch; export then failed with “Trace is malformed; instrument run data is missing”. That trace is not used as a timing result or root-cause diagnosis. The five XCTest responsive-launch samples are the usable startup evidence, with the limitations above.

Host load was approximately 12.5 at the initial measurement. No unrelated apps were stopped. There are no continuous app timers/animation loops or networking in the inspected code. Existing rendering/encoding/decoding run off-main, and the preview is revision-cached, but source properties are not frame-pacing or energy measurements. MetricKit/analytics were not added. The skill’s generic thresholds and examples are treated as heuristics rather than App Store guarantees or a reason to override the app’s offline/privacy rules.

## Build 10: explicit document types and translucent watermark

The previous stamp’s large recipient, fine rules and opacity obscured document details. RvIG’s KopieID FAQ and official watermark illustration informed a simpler recipient/purpose/date treatment. The illustration was inspected in the browser; it is a diagram, not a verified screenshot of the exact current app. Research and decisions are recorded in docs/plans/2026-11-08-document-watermark-design.md.

Documents now starts with four named types/sides, followed by country-profile navigation and a separate searchable country directory. Native lists replace flags, regional groupings and abbreviated kinds. The watermark has two equal-size/weight lines at 30 degrees with translucent red multiply blending over document pixels and a clipped light pass over opaque masks. Decorative rules and the oversized recipient are removed. No OCR, mask geometry or file-format code changed; PRIVACY was updated for the changed exported appearance.

- `swift test`: 18 core checks passed, including a new regression retaining every pure-black source-print pixel while requiring visible watermark pixels on the paper between lines. Existing opaque-mask, every-page marking, page-gap and image-only PDF checks passed. The black-pixel equality is before lossy JPEG encoding; it does not establish all coloured/faint printing remains equally readable.
- Initial normal-size Simulator checks: Documents/country search/detail, full review→watermark→copy→zoom→Close, and long-recipient keyboard/system sharing passed (3/3), no runtime warnings. Rendered Documents, country details and final watermarked copy were inspected under build/Revision10/light.
- Initial compact dark/increased-contrast/maximum-text run: PDF save, JPG cancel and PDF sharing passed; document browsing failed because the test expected a virtualized offscreen row without scrolling. Visual evidence also found narrow icon-leading labels split words. Full-width text with icons above at accessibility sizes and removal of the redundant root section heading correct the layout. The test now scrolls through each type and the country directory; `CompactFinal.xcresult` passed the affected journey (1/1), no runtime warnings. Final compact Documents and saved-PDF screenshots were inspected.
- `FinalLight.xcresult` passed the final normal-size document navigation and actual PDF-save/JPG-cancel/PDF-share paths (2/2), with no runtime warnings. The final document page was inspected after removing the redundant section heading.
- Placement is fixed, not OCR-aware. Lettering still intersects some fields; multiply blending improves readability and is not collision avoidance. Faint/coloured printing, very long inputs, physical printing/recapture, manual VoiceOver and real-device frame pacing remain open. Country-profile lists do not prove every document version has been validated.

Build 10 upload completed at 18:11 Amsterdam time on 8 November. Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing. The archive passed strict signature verification, has the stable bundle ID/version 0.1.0 (10), retains the selected-C 1024 px AppIcon and contains no test resources. The browser session had expired at the subsequent verification attempt; Ready to Test / installation availability is not confirmed.

## Build 9: selected C mark, no Home branding

The owner selected C, requested a more prominent lock, and rejected any logo on Home. Production artwork and the in-app privacy-cover geometry now use the larger corner lock. Home has no visible brand mark or wordmark; only the Documents toolbar control and source actions remain. Functional screen titles stay compact. No recognition, masking, watermark or export code changed.

`SelectedC.xcresult` passed Home/Documents/search and the full review→watermark→copy→zoom→Close journey (2/2), with no runtime warnings. The final logo-free Home screenshot was inspected under build/BrandStudy/home.png. Source icon artwork was inspected at 1024 px and in the small-size/dark comparison; the lock is deliberately larger than the initial C. These focused light-mode journeys are not new evidence of maximum-text layouts, VoiceOver navigation or device frame pacing.

Build 9 upload completed at 17:48 Amsterdam time on 8 November: Xcode reported Upload succeeded / EXPORT SUCCEEDED and Processing; the browser independently confirmed build 9 Processing. Strict archive signature and stable bundle identity/version were verified. The full-size compiled icon is present and the embedded 120 px optimized PNG was decoded with Xcode’s pngcrush and visually verified against the selected C lock. No fixture images or test bundles are embedded. Installation availability is not yet confirmed.

## Earlier exploration: compact brand header and privacy-logo studies

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
