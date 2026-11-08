# Interface direction

Maske is a private document tool. The document and the next action take priority. The owner asked for a quieter Nordic character, more usable interactions and very little explanation text.

## Visual roles

- Use SF system typography and native navigation. Large title for the app's entry screen, inline titles for tasks, body text for actions and values, subheadline/caption for context. No custom display font or marketing headline.
- Use the semantic colours in Theme.swift: cool paper, white/dark surface, graphite text, readable muted text and one grey-blue accent. The opaque export mask colour remains separate from interface colours.
- Keep source choices and input rows flat and aligned. Use thin rules where grouping needs them. Document previews have a small edge radius and hairline, without floating-card shadows.
- At accessibility text sizes, stack input labels and document types vertically. Keep source choices and their footer in the same scrollable area. Omit source-row symbols at those sizes and keep other decorative symbols compact so that text has room to grow.
- Use standard spacing roles: 8–12 points within controls, 20–24 at screen edges, 28 between task groups. Source rows and editor handles have touch-friendly targets. A small text mask is selected by its nearest edge within 22 points; its exported geometry is unchanged.

## Interaction roles

- Home presents three sources directly. No introduction, tutorial or permanent history.
- Review keeps the document prominent. Bulk mask switches live in the native Masks menu. Tapping a mask opens its editor; drawing a new mask opens that editor for precise adjustment.
- Use native scrolling, keyboard behaviour, menus and sheet transitions. Custom drawing-mode feedback uses a short fade and respects Reduce Motion. Corner dragging tracks the gesture directly.
- Importing and recognition acknowledge work immediately, allow Cancel, and discard late results from an old session. A currently running Vision request may finish offscreen; further pages are skipped.
- Share keeps the preview in memory and writes a JPEG only when Share copy is tapped. The active recipient, purpose and mask revision must match the rendered preview before sharing is enabled. The preview itself opens a zoomable inspector.
- While entering copy details, the keyboard owns the bottom area. Next moves from Recipient to Purpose; the focused row scrolls above the keyboard. Done dismisses the keyboard and restores Share copy.
- Use native alerts for actual failures, with a short recovery action. Preserve input on share failures. Privacy covers apply to document screens and modal previews when the scene is inactive.

## Verification

Run scripts/ui-check.sh for app-state regressions and the complete synthetic UI journey. Inspect the attached screenshots at normal and accessibility text sizes, in light and dark appearance, and on a compact iPhone. Run scripts/check.sh before committing. Source images used for UI checks are generated fixtures only.

The direction follows Apple's guidance on [purposeful, interruptible motion](https://developer.apple.com/design/human-interface-guidelines/motion) and [honest progress with cancellation](https://developer.apple.com/design/human-interface-guidelines/progress-indicators). It does not imply measured frame-rate improvements or a complete accessibility certification.
