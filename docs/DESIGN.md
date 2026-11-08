# MaskCopy interface

The owner rejected build 5's flat landing list and hidden mask menu. Revision 6 uses a focused ID-copy workflow, informed by the actual official KopieID screenshots and MaskID's published functionality. Competitor assets and code are not included.

## Journey

- Home: an abstract, clearly redacted document; one primary Scan action; secondary Photos and Files. No slogan, tutorial, recent-document library or explanatory paragraph.
- Hide: document first, directly visible native field switches, optional Add box and precise corner editing. The reviewed polygons remain the export polygons.
- Watermark: recipient, purpose and date. Input stays local to this screen. Next/Done and focus scrolling support the keyboard. No bitmap rendering runs while typing.
- Share: generate the immutable copy in the background before navigating here. Show those exact pixels in a native zooming viewport, with one Share action. Returning to edit preserves the draft; matching copies are reused. Only Share writes a JPEG.

## Visual and motion roles

Theme.swift owns the warm paper/graphite/deep blue palette, system typography, restrained document motif and shared controls. Physical document artwork stays light in dark mode, so its dark masks remain apparent. Short labels explain actions; progress uses Hide / Watermark / Share. Accessibility sizes show the current stage and count instead of squeezing three labels, stack source choices and dates, and shorten primary labels without reducing the selected text size.

Opaque charcoal replaces the pale blue-grey redaction. A single diagonal recipient/purpose/date block is burned into every page. Text is dark over the document and light where it intersects masks, so unmasked text remains readable. There is no detachable watermark footer, dense repeating pattern or recoverable blur.

Forward/back changes use the native navigation stack with explicit animated path mutations. The document is the source of the native iOS 18 zoom transition into its editor. Scan decoding begins after the camera cover dismisses. UIKit's UIScrollView owns pinch, momentum and double-tap zoom; the bitmap is installed once rather than resized on every slider tick. Corner controls retain 44-point screen targets at every zoom and update the polygon directly. No opacity animation weakens a redaction. Reduce Motion selects a gentler navigation animation, and native scroll/zoom transitions remain system-owned.

## Product distinction and limits

MaskID already offers on-device OCR, manual masking, watermarks, flattened exports and metadata checks. Those are shared capabilities, not unique advantages. MaskCopy focuses on country/document-specific geometry, MRZ and number checks, complete photo rectangles and secondary portraits/windows, followed by precise review. Its current specimen coverage and recognition failures are in KNOWN_ISSUES. No claim of superior accuracy or universal performance is supported by the current evidence.

Verification and measured performance are in AUDIT.md. Physical-camera behavior, frame pacing on an iPhone and manual VoiceOver use still require device testing. Official motion reference: https://developer.apple.com/videos/play/wwdc2024/10145/ .
