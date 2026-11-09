# Changelog

All notable changes to MaskCopy are listed here. Versions follow [Semantic Versioning](https://semver.org).

## Unreleased

- Add repeatable physical-device recognition checks with test-only generated/official specimen resources, relative DEBUG fixture paths for UI tests and first-device registration support.
- Record the first iPhone launch/render/recognition/editor measurements and the partial hitch trace; keep locked-phone watermark/specimen checks explicitly open. Production Release behavior remains unchanged.

## [0.1.0] - 2026-11-09

Build 11: fixes from the requested three-skill audit. Uploaded 9 November at 09:08 Amsterdam time; Apple reports Processing. Installation availability is not yet confirmed.

- Import every PDF/scan page up to four; require explicit thumbnail selection from longer inputs instead of silently truncating. Decode selected pages serially and downsample photo/file images with ImageIO.
- Make Add box open an adjustable draft directly, with a native page menu for multi-page documents. Save commits and Cancel discards; retain semantic body/corner adjustment actions.
- Move the watermark separately on each page with direct dragging, Reset and accessibility move actions. Fit its selection bounds to the text; render final pixels off-main after Save and prevent stale-copy export.
- Serialize temporary export writes and background cleanup. Cancel active Vision requests on a best-effort basis and retain session-generation guards. Match the native launch background to Home.
- Stack page-selection rows at accessibility text sizes and shorten editing titles there. Preserve the logo-free Home, selected-C icon, offline processing and opaque flattened exports.
- Replace the shared-blank-raster performance fixture with four independently drawn pages; report measured limits in AUDIT rather than claiming device performance.

Build 10: document information and readable watermarks. Uploaded 8 November at 18:11 Amsterdam time; Apple reports Processing. Installation availability is not yet confirmed.

- Organize Documents by Passport, National ID card, Residence permit and Driving licence, with photo-page/front-and-back labels and searchable country profiles. Replace emoji regions and abbreviated document names with native navigation.
- Use two uniform translucent diagonal watermark lines instead of a decorated purpose stamp. Multiply blending preserves black printing before JPEG encoding; a light clipped pass keeps the watermark visible over opaque masks. Keep recipient, purpose and date inside every flattened page.
- Stack document icons above full-width text at accessibility sizes. Keep photos/PDF import and review reminders brief.

Build 9: privacy mark and quieter navigation. Uploaded 8 November at 17:48 Amsterdam time; Apple reports Processing. Installation availability is not yet confirmed.

- Adopt the owner-selected C AppIcon, with a larger corner lock and the existing paper/card/redaction identity. Match the privacy-cover mark to the selected artwork.
- Remove all brand text and logos from Home. Keep direct source actions and the Documents control; use compact inline functional titles elsewhere.
- Retain three reproducible privacy-logo studies for comparison.

Build 8: native Liquid Glass alignment. Uploaded 8 November at 17:36 Amsterdam time; Apple reports Processing. Installation availability is not yet confirmed.

- Adopt native glass/glassProminent source and action buttons on iOS 26+, grouping related controls with GlassEffectContainer. Keep standard iOS 18–25 fallbacks.
- Use a native leading title on Home and adaptive large content titles. Keep editor confirmation/cancellation in standard navigation positions.
- Replace custom opaque footer backings with safeAreaBar and the system scroll edge. Group editor controls in one regular-glass surface and unify content-group radii.
- Let native button styles supply label treatment and touch motion. Add increased-contrast variants for the app's text, separators and accent. Keep document pixels and opaque export masks unchanged.

Build 7: direct editing and explicit export. Uploaded 8 November at 16:46 Amsterdam time; App Store Connect confirms Processing. Installation availability is not yet confirmed.

- Completely redesign Home around one scan control and two lightweight import actions. Draw a coherent source icon family in the app's theme; remove the illustration, introduction heading, large source cards and all three-stage trackers.
- Add whole-mask dragging on Review and in the enlarged editor, preserving the polygon's shape and clamping it at page edges. Keep corner editing and outside-mask panning.
- Redesign the watermark as a smaller, lower, higher-contrast purpose stamp with distinct type sizes and fine rules. Keep long text, every-page marking and fully opaque redactions.
- Show JPG/PDF selection and separate Save/Share actions on the final preview. Save opens Files directly; PDF contains only flattened JPEG pixels without text layers, annotations or a metadata dictionary. Replace the ambiguous Done action with Close.
- Add restrained press feedback, pickup/save haptics and a checkmark transition after successful saving. Respect Reduce Motion and keep recognition/encoding off the main actor.

Build 6: MaskCopy, a document-focused workflow. Uploaded on 8 November at 13:26 Amsterdam time; Apple initially reported Processing; later App Store Connect verification confirmed internal installation of 0.1.0 (6). The backend title was separately saved as MaskCopy: Safe ID Copies.

- Rename the app's display/product name and GitHub repository to MaskCopy. Keep the existing bundle ID and internal module names so installed copies and TestFlight continue updating the same app.
- Rebuild Home around a document motif, one primary scan action and secondary photo/file sources. Use directly visible mask switches and explicit Hide → Watermark → Share stages.
- Replace pale masks with opaque charcoal. Burn recipient, purpose and date into every page as one diagonal watermark, using dark lettering on the document and light lettering on masked areas. Remove the separate footer.
- Keep watermark input local to its screen; render once off the main actor before showing the final copy, cache matching copies, and invalidate them after edits. Generate the JPEG only when sharing.
- Replace layout-driven zoom with native pinch, momentum and double-tap zoom. Keep corner targets at 44 screen points at every zoom and connect the editor presentation to its source document.
- Add copy-cancellation/cache regressions, every-page watermark checks, native zoom/target-size tests, an isolated synthetic-photo import journey and recorded launch/render metrics. Device frame pacing remains unverified.

Build 5: a quieter native interface and safer session flow.

- Replace the branded landing layout and floating preview cards with flat source choices, system typography, a cool neutral palette and one grey-blue accent. Keep the document prominent and explanation text brief.
- Move bulk mask switches into the native Masks menu. Make small masks easier to select and open the corner editor immediately after drawing a box.
- Keep Share to two labelled fields and one action. Tap the preview to inspect the complete copy with zoom; search countries in Documents.
- Decode imports off the main actor, show opening/reading progress and allow cancellation. Late import or recognition results cannot replace a newer session.
- Bind previews to the current document, masks and recipient details. Render previews in memory and write a JPEG only for an explicit Share action. Clean abandoned temporary copies on the next launch.
- Add app-state/file-lifecycle regressions and UI journeys for recovery, mask controls, keyboard entry and the native share sheet. The recognition engine and icon artwork are unchanged.

Build 4: precise photo review and readable copies.

- Tighten complete photo rectangles using verified frames, connected portrait pixels and neighbouring fields. Include pale shoulders on the Dutch D1 licence using its MRZ as a local anchor.
- Cover transparent and small secondary portraits on the reviewed Dutch ID/licence and Norwegian ID/licence specimens. Retry small passport faces in an enlarged crop, including the Chinese passport's secondary portrait.
- Adjust any existing mask with four draggable corners and 1–8× zoom. Save changes the export polygon; Cancel discards the edit.
- Replace black masks with an opaque blue-grey fill. Put recipient, purpose and date in a wrapping footer, with one light recipient watermark per page instead of dense repeated text.
- Preserve residual perspective while fitting individual text lines. Reject invalid correction geometry and keep source-coordinate metadata consistent if correction fails.
- Add Norwegian ID and paired-window synthetic regressions, an optional specimen annotation manifest for `maske eval`, and geometry/opaque-rendering tests. Device validation and remaining recognition limits are recorded in KNOWN_ISSUES.

Build 3: mask fixes from specimen testing.

- Keep estimated portrait masks within nearby field columns when several separate text rows mark the same boundary.
- Reject text fits that spread into adjacent rows or rotate away from the text. Use distinct Vision character boxes to guide cuts between labels and values.
- Correct the document orientation when the full OCR pass consistently finds upside-down text.
- Recover missing or split passport MRZ rows with a cropped OCR pass and row geometry. Recognise the one-line Dutch driving licence MRZ, including rows without fillers.
- Keep licence field rules off passports, recognise Norway's 4d value beside the expiry date, and stop the Chinese driving licence address mask before the issuer's stamp.
- Fail the synthetic check on missed or overmasked fields. Let the angle check compare against known field positions.

Build 2 (2026-11-07): masks that fit.

- Photos taken at an angle, turned or with background now work: the document is found, straightened and turned upright before anything is read, and that straightened document is what you review and share.
- Masks follow the text exactly: fitted to the ink of the characters, at the text's own angle, with a thin margin. A value next to its label no longer takes the label with it.
- The machine-readable zone mask covers its characters only, no longer the full width of the photo.
- The portrait mask uses the portrait's own edge when it has one.
- A supported list of 27 countries (Europe, North America, Australia and New Zealand, East and Southeast Asia); documents from elsewhere get a warning to check every box.
- Known problems are listed in docs/KNOWN_ISSUES.md.

Build 1:

The first prototype, for the team to try.

- Scan with the document camera, or choose photos, an image or a PDF; front and back become one copy.
- Finds the machine-readable zone (ICAO 9303 TD1, TD2, TD3 and the ISO 18013 licence line), personal and document numbers with their check digits for about 45 national formats, labelled fields in many languages, numbered licence fields (EU model, ISO 18013, AAMVA), the card access number, addresses, faces and barcodes.
- Recognises the document's kind and country, with profiles for 50 European countries, the US, Canada, Mexico, Australia, New Zealand, China, Hong Kong, Taiwan, Japan, South Korea, Singapore, Malaysia, India and Brazil.
- Review: tap a box to show or hide it, switch a whole kind on or off, draw your own boxes.
- The shared copy: masks painted in, the recipient, purpose and date written across it, at most 1600 pixels wide, no metadata. The temporary file is deleted when you are done.
- The `maske` tool and 41 synthetic documents to check the engine.
