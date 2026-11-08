# Portrait boundaries and readable copies

The owner tested a Dutch driving licence and Norwegian ID card and requested tighter photo masks, coverage of transparent portrait windows and small duplicate portraits, and a less intrusive appearance. They specified the complete photo's rectangular boundary, rather than the person's silhouette. This follows the earlier request to prioritise Norway, the Netherlands and China, then compatible European layouts. US and Australian variations are deferred.

## Recognition

Keep Claude's existing pipeline: straighten the page, recognise text and faces offline, associate fields with labels and standards, fit the ink, merge, review, export. Improve the weak geometry rather than replace the engine.

Use one explicit coordinate mapping for rectangle observations. Preserve thin photo frames detected before rectification by mapping them into the corrected image. Reject apparent frames that cut across the face or taper like a person's silhouette. A small safety margin covers resampling at a real frame edge.

When there is no verified frame, measure substantial connected portrait pixels inside bounds limited by neighbouring text. Include disconnected clothing, suppress fine security print, and use colour separation only for monochrome portraits with measurable separation from the background. OCR fields act as barriers. This is still an estimate: a borderless printed photo has no independently verifiable rectangular frame.

Search for secondary passport faces in an enlarged crop. Use detected edges, document family and feature arrangement for the Dutch licence's paired windows, Dutch ID window and Norwegian ID/licence windows. The Norwegian ID back's wide security patch needs a separate measurement of the small portrait within it. These rules do not establish coverage for every historical document version.

Fit text in a projectively rectified local patch and map the resulting four corners back through the same homography, retaining residual taper.

## Review and export

Tap an existing mask to adjust its four corners. Use native scrolling and 1–8× zoom for small photos and windows. Save updates the actual export polygon; Cancel leaves it unchanged. Temporary translucency is confined to this in-memory adjustment view.

Replace black with an opaque blue-grey fill shared by Review and export. Keep the reviewed polygon without a separate fat outline. Put recipient, purpose and date in a wrapping footer outside the document, with one faint diagonal recipient mark per page. This replaces the old dense tiled watermark at the owner's request. Update PRIVACY and DECISIONS together.

## Verification

Regenerate and evaluate all 43 synthetic documents, including new Norwegian ID fronts/backs and paired Dutch licence windows. Use a separate local specimen manifest with photo, window, number and preserved-field annotations. Keep specimen images ignored. Check original and exported images by eye as well as numerical coverage; the existing 98% threshold cannot prove that every photo edge is covered. Run rotation/perspective regressions, opacity and homography tests, app builds, and an isolated simulator UI check of adjustment and export.

Remaining work belongs in KNOWN_ISSUES, especially uncertain page correction, borderless portraits, overlapping security portraits and device verification.
