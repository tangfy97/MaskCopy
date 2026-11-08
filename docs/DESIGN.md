# MaskCopy interface

Revision 9 keeps the native materials introduced in revision 8 and adopts the owner-selected privacy mark with no branding on Home. Revision 8 aligned the existing minimal workflow with Apple's current Liquid Glass guidance, after reviewing the WWDC26 Design guide, current Materials HIG and adoption/custom-view documentation, and the WWDC25 design-system session. It keeps short labels, the paper/ink/fjord theme and direct document manipulation.

## Native material and navigation

The owner rejected the oversized brand title and then the logo header. Home has no visible brand text or mark; the upper toolbar contains only the Documents control. Functional screens use compact native inline titles; the corner editor keeps the standard Cancel/Save arrangement. Apple's leading-typography guidance covers key moments such as alerts/onboarding, rather than requiring every navigation title or control to align left.

On iOS 26 and newer, source and action buttons use glass/glassProminent styles. The framework owns touch highlights, vibrancy, shape and motion. Related controls use GlassEffectContainer; bottom controls use safeAreaBar for the system scroll edge. Remove the old opaque footer backing. A single regular-glass editing surface groups zoom, Hide and Reset. Document pixels, redactions, watermark and form content use their original content surfaces.

Primary actions use prominent glass, secondary actions use regular glass, and native toolbars retain their built-in group backgrounds. Controls use capsule/circle shapes; content groups have consistent 24-point radii, and the editing surface uses 28 points. App ink, separators, accent and muted text have explicit increased-contrast variants. Prominent tinted controls use the theme’s on-accent foreground; secondary buttons keep native accent treatment. Editor actions stack at accessibility sizes, and accessible export sheets use a stable large detent. System glass adapts to reduced transparency and contrast preferences. iOS 18–25 keep standard-button/material fallbacks. No networking or rendering-output changes are introduced.

Sources: [WWDC26 Design](https://developer.apple.com/wwdc26/guides/design/), [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [Design system session](https://developer.apple.com/videos/play/wwdc2025/356/).

## Home and icon language

Home contains one central Scan control and lightweight Photos/Files actions. No large brand text, hero illustration, large cards, slogan, tutorial or introductory heading. The supported list is behind the native information control. At accessibility sizes the source actions may stack and the whole layout can scroll without shrinking the selected text size.

The owner selected privacy-logo C and requested a more obvious lock. The AppIcon now has a larger corner lock, with its body increased from 172 to 224 normalized units and its shackle from 106 to 126. The card/redaction identity remains intact. `scripts/icon.swift` renders production artwork; `scripts/brand-study.swift` reproduces the comparison studies in `Design/Studies/2026-11-08`. Theme.swift uses the same selected geometry for the app-switcher privacy cover. No decorative logo is shown on Home.

Three source symbols share a 24-point drawing grid, round joins and consistent stroke ratios. The scan symbol contains an ID card with a redacted line, keeping the product identity inside a functional control. Icons have accessible names, and the brief Scan/Photos/Files labels make the choices recognizable. Existing system icons remain for familiar editing and export actions.

Lunar's official redesign and Home screenshot informed immediate task access and clear grouping, not a copied banking dashboard: https://www.lunar.app/en/personal/new-lunar-experience . No competitor image or code is bundled. Theme.swift owns custom drawing and visual treatment.

## Document information

Documents starts with four native rows: Passport (photo page), National ID card, Residence permit and Driving licence (front and back). Each type opens its matching country profiles. Countries offers a searchable alphabetical list and a per-country list of full document names. Remove emoji flags, regional sections and abbreviated ID/Residence/Licence strings. Keep only a brief photos/PDF import label and review reminder. These are recognition profiles, not a claim that every historical document version has been validated.

## Editing and export

Hide shows the document and direct native field switches. Drag a mask to translate the entire polygon, preserving perspective and size and stopping at page edges. Tap to open the enlarged editor: drag inside the polygon to move it, outside to pan the document, or use the 44-point corner targets for precise resizing. The edited polygons are the exported polygons.

Watermark contains recipient, purpose and date. Input stays local; no bitmap work runs while typing. Preview renders off-main before navigation and caches matching document/mask/input revisions. Returning to edit keeps the draft. There is no stage/progress tracker.

Your copy shows the exact immutable output pixels in a native zooming viewport. JPG/PDF selection and separate Save/Share actions stay visible. Save opens the native Files destination picker and confirms completion with a checkmark in the existing button. Save/share callbacks explicitly clear presentation state, so canceling or finishing restores the same copy. Share opens the system activity sheet using the selected format. Close names leaving the workflow; it replaces Done. Only explicit Save or Share writes a temporary file. A saved destination copy belongs to the user and survives the session.

PDF is one image-only page containing the same flattened JPEG pixels as JPG, including multiple source sides when present. It contains no original image, recoverable mask layer, searchable text, annotations or metadata dictionary.

## Watermark and motion

Every page has a simple 30-degree, two-line watermark: “Copy for [recipient]”, followed by purpose and date. Both lines use the same medium-weight type. There is no decorative rule, oversized recipient, border or removable footer. Translucent red lettering uses multiply blending over the document, preserving pure black printing rather than painting over it. A clipped light pass makes lettering visible on opaque masks. Long text wraps and fits. The angle/position are fixed; this is not OCR-aware placement, and faint or coloured print still needs visual review.

Motion explains actions: a system-owned glass-button press (a short interruptible press on older iOS), native navigation/source-linked editor transitions and a symbol replacement when saving succeeds. Pickup and save completion provide light haptic feedback. There are no looping decorations or entrance delays. Reduce Motion governs native effects; older-system fallbacks remove custom press scaling. UIScrollView owns pinch, double-tap and momentum; the image is installed once. Recognition and file encoding remain off-main and do not run on gesture or animation frames.

## Limits

Shared OCR/masking/watermark features are not unique to MaskCopy. Its focus is country/document-specific geometry followed by precise review. Known recognition limits and remaining physical-device performance/accessibility checks are in KNOWN_ISSUES. Simulator tests and visual inspection do not establish frame pacing on an iPhone. Verification is recorded in AUDIT.md.
