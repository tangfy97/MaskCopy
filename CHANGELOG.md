# Changelog

All notable changes to MaskCopy are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-11-08

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
