# MaskCopy interface

The owner rejected revision 6's homepage, three-stage tracker, weak watermark and ambiguous Done action. Revision 7 keeps the warm paper, graphite and deep blue theme while removing the introductory layout and progress chrome.

## Home and icon language

Home contains a compact native brand title, one central Scan control and lightweight Photos/Files actions. No hero illustration, large cards, slogan, tutorial or introductory heading. The supported list is behind the native information control. At accessibility sizes the source actions may stack and the whole layout can scroll without shrinking the selected text size.

Three source symbols share a 24-point drawing grid, round joins and consistent stroke ratios. The scan symbol contains an ID card with a redacted line, keeping the product identity inside a functional control. Icons have accessible names, and the brief Scan/Photos/Files labels make the choices recognizable. Existing system icons remain for familiar editing and export actions.

Lunar's official redesign and Home screenshot informed immediate task access and clear grouping, not a copied banking dashboard: https://www.lunar.app/en/personal/new-lunar-experience . No competitor image or code is bundled. Theme.swift owns custom drawing and visual treatment.

## Editing and export

Hide shows the document and direct native field switches. Drag a mask to translate the entire polygon, preserving perspective and size and stopping at page edges. Tap to open the enlarged editor: drag inside the polygon to move it, outside to pan the document, or use the 44-point corner targets for precise resizing. The edited polygons are the exported polygons.

Watermark contains recipient, purpose and date. Input stays local; no bitmap work runs while typing. Preview renders off-main before navigation and caches matching document/mask/input revisions. Returning to edit keeps the draft. There is no stage/progress tracker.

Your copy shows the exact immutable output pixels in a native zooming viewport. JPG/PDF selection and separate Save/Share actions stay visible. Save opens the native Files destination picker and confirms completion with a checkmark in the existing button. Save/share callbacks explicitly clear presentation state, so canceling or finishing restores the same copy. Share opens the system activity sheet using the selected format. Close names leaving the workflow; it replaces Done. Only explicit Save or Share writes a temporary file. A saved destination copy belongs to the user and survives the session.

PDF is one image-only page containing the same flattened JPEG pixels as JPG, including multiple source sides when present. It contains no original image, recoverable mask layer, searchable text, annotations or metadata dictionary.

## Watermark and motion

Every page has a compact 15-degree purpose stamp lower in the document: a tracked COPY FOR label, a stronger recipient line and smaller purpose/date text between two fine rules. Long input wraps and fits rather than truncating. Higher-contrast dark type covers the document; the same type becomes light over opaque masks. There is no detachable footer. Fixed placement can still overlap content on unfamiliar layouts; automatic placement is not claimed.

Motion explains actions: a short interruptible scan-button press, native navigation/source-linked editor transitions and a symbol replacement when saving succeeds. Pickup and save completion provide light haptic feedback. There are no looping decorations or entrance delays. Reduce Motion removes the custom press scaling. UIScrollView owns pinch, double-tap and momentum; the image is installed once. Recognition and file encoding remain off-main and do not run on gesture or animation frames.

## Limits

Shared OCR/masking/watermark features are not unique to MaskCopy. Its focus is country/document-specific geometry followed by precise review. Known recognition limits and remaining physical-device performance/accessibility checks are in KNOWN_ISSUES. Simulator tests and visual inspection do not establish frame pacing on an iPhone. Verification is recorded in AUDIT.md.
