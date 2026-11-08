# Copy workflow, revision 6

The owner rejected build 5's flat homepage and coarse flow, motion, performance and pale masks. Focus on page transitions, not landscape support. Keep the current offline engine and precise polygons. MaskID was rejected as a name after finding an existing iPhone app with the same purpose; the owner subsequently chose MaskCopy.

## Evidence and direction

RvIG's official KopieID listing and screenshots show one primary start action, directly visible redaction switches, dark solid masks, a prominent diagonal watermark and explicit stages. Its FAQ describes capture, choosing fields, watermarking and sharing. References: https://www.rvig.nl/veelgestelde-vragen-kopieid-app and https://apps.apple.com/nl/app/kopieid/id932970330 . No competitor assets or code are shipped.

Three approaches were considered: restyling build 5, a single elaborate editor, and separating decisions into Hide → Watermark → Share. Choose the third. It makes controls discoverable and removes bitmap rendering from keyboard input. Home has a deliberate document motif, one primary scan action and secondary photo/file imports. All styling remains in Theme.swift; no marketing prose or tutorial is added.

Review shows the document and native field switches. Watermark contains recipient, purpose and date; text editing stays local to that screen. Continue generates one immutable full-resolution copy away from the main actor before opening Share. Sharing and inspection use those same pixels. Returning to change fields preserves the draft; stale/cancelled work cannot reopen a session.

A native UIScrollView handles pinch, double-tap and momentum rather than resizing SwiftUI content on every zoom update. Four corner controls track the finger directly and keep a consistent on-screen target size. Forward/back navigation uses the system stack with explicit animated mutations; no full-resolution rendering starts on a transition's main-thread path. Reduce Motion uses gentler feedback.

Masks become opaque charcoal. Each document receives a legible diagonal block containing recipient, purpose and date, rather than a faint recipient-only line and detachable footer. Preserve all watermark text, wrapping and fitting it into a bounded block. Do not animate redaction opacity or weaken the exported fill.

## Checks

Inspect actual Home, Review, Watermark, Share and editor screens, including compact/dark/larger text. Exercise cancel, back, field toggles, drawing, zoom/pan, Save/Cancel, watermark input, final pixel sharing and repeated navigation. Add renderer coverage for contrast, full opacity and watermark fields on every page. Record render/launch/transition measurements and tool limitations. No attached physical iPhone was found, so simulator results cannot establish real-device frame pacing. Update AUDIT, KNOWN_ISSUES and PRIVACY with truthful results.
