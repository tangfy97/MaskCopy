# Aligning MaskCopy with Apple's Liquid Glass design system

The owner requested more Liquid Glass and a researched alignment with current Apple design details. Consulted Apple's WWDC26 Design guide, the current HIG Materials chapter, Adopting Liquid Glass, Applying Liquid Glass to custom views, and the WWDC25 new-design-system session. The installed iOS 27.2 SDK was also checked for API availability. WWDC25's typography guidance specifically identifies alerts/onboarding as key moments for stronger leading alignment; it does not require every control or navigation title to be left-aligned.

## Decisions

- Keep revision 7's minimal source chooser, custom icon identity and short labels. Use the system inline-large leading title at Home. Content pages use native large titles with system scroll collapse. The corner editor keeps standard Cancel/Save navigation so neither action is hidden by title-mode overflow.
- Use native glassProminent/glass button styles on the source chooser and the Save/Share/Continue actions. The framework owns touch response, vibrancy, specular highlights and accessibility adaptation. Keep a single regular-glass editing control surface and native toolbars. Do not put glass onto document pixels, masks, the watermark or form content.
- Replace the opaque custom footer backing with safeAreaBar and its system scroll-edge treatment. GlassEffectContainer groups related controls for the rendering path. Use a dedicated on-accent foreground for prominent tinted controls; keep secondary labels in their native accent treatment.
- Use consistent capsule/circle controls and rounded 24-point content groups, with a 28-point editing surface. Give the app's ink, accent, separators and secondary text explicit increased-contrast variants. System glass handles reduced transparency; do not emulate it with stacked blur layers.
- Gate iOS 26 APIs, preserving iOS 18 standard-button/material fallbacks. No recognition/export/watermark changes in this revision.

## Validation

Re-run import/review, direct movement/corners, keyboard, actual save/cancel/share and return navigation. Inspect light, compact dark/increased-contrast/maximum-text layouts, scrolling under the bar, and the corner editor. Check reduced visual effects with real system settings when possible; label any unavailable check explicitly. Simulator functional evidence is not a device frame-pacing guarantee.

Sources:
- https://developer.apple.com/wwdc26/guides/design/
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/videos/play/wwdc2025/356/
- https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/inlinelarge
