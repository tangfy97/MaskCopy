# Decisions

Why Maske is the way it is. Newest last. Change a decision only with the owner, and record the change here.

| Date | Decision | Why |
|---|---|---|
| 2026-11-07 | Build an alternative to KopieID that works for documents from any (supported) country | KopieID only handles Dutch documents; the owner's audience includes people who moved between countries |
| 2026-11-07 | Native iOS app (SwiftUI), local only | The owner asked for a local, private phone app; scanning is a phone task |
| 2026-11-07 | Name **Maske** (Norwegian for "mask"); App Store name "Maske: Privacy-First ID Copy" | TangSpark apps have short Norwegian names (Kvikkshot, Glimt, Rydd, Spolo); the owner wanted it simple and privacy-first, and asked for "privacy first id copy" in the store name |
| 2026-11-07 | Nordic, minimal design: paper, ink and one cold blue (`Theme.swift`), standard controls | The owner's request; matches the house style |
| 2026-11-07 | No templates per country; rules from international standards (ICAO 9303 MRZ, EU driving licence fields, ISO 18013, AAMVA) plus national number formats with check digits | Covers many documents with little code; check digits keep false matches rare |
| 2026-11-07 | Every suggested mask is on by default, including the photo; the user can show any of them | Hiding too much is safer than too little; the Dutch government advises crossing out the photo and BSN on copies |
| 2026-11-07 | Masks are painted into the pixels, never blurred; the copy is re-encoded at most 1600 px wide with no metadata; a watermark "COPY FOR <RECIPIENT> · <PURPOSE> · <DATE>" is tiled across the whole document | Blur and pixelation can be reversed; metadata can hold location; the watermark stops the copy being reused elsewhere (as KopieID does) |
| 2026-11-07 | Nothing is kept: the session lives in memory, the temporary file is deleted when done, the app is covered in the app switcher | Privacy is the product |
| 2026-11-07 | Open source (Apache 2.0), public on GitHub | House standard; lets anyone check the privacy promise, since iOS cannot forbid networking the way the macOS sandbox can |
| 2026-11-07 | TestFlight first, internal group TangSpark with automatic distribution | The owner tests on their own iPhone |
| 2026-11-07 | Straighten the document before reading; layout rules measure from the MRZ or the text, never from the photo's edges | Build 1's masks landed in the wrong place on real photos with background or at an angle |
| 2026-11-07 | Masks fitted to the ink, at the text's own angle, as four-cornered shapes | The owner asked for masks that cover exactly the needed area, no more and no less |
| 2026-11-07 | When covering a little extra and leaving a character visible conflict, cover | A visible digit of a personal number defeats the purpose; extra cover only costs a little readability |
| 2026-11-07 | A supported list (27 countries) instead of "every country"; others get the general rules and a warning | The owner: support the most common countries first, grow the list step by step |
| 2026-11-07 | Test images: synthetic documents, PRADO and Commons specimens, never real people's documents; downloaded images are not committed | Privacy and copyright |
| 2026-11-07 | Collect PRADO images through a normal browser, not by getting around its bot protection | Respect the site's rules |
| 2026-11-07 | Document open bugs instead of fixing all at once; ship prototype builds in between | The owner's preference: "一步一步来，先做出一个prototype" |
| 2026-11-08 | Cover the complete photo rectangle, including separate secondary portraits and transparent windows; allow geometry-anchored feature corrections for verified document families | The owner explicitly requested precise rectangular photo boundaries and country calibration, starting with Norway, the Netherlands and China; a face silhouette alone leaves part of the photo visible |
| 2026-11-08 | Replace dense tiled watermarks with a wrapping recipient/purpose/date footer and one faint diagonal recipient mark per page; use opaque blue-grey masks | The owner found black blocks ugly and the repeated watermark obstructive. Opaque pixel replacement remains unchanged; the new layout prioritises reading the document |
| 2026-11-08 | Add zoom and direct four-corner editing of existing masks | Automatic borders on borderless and security portraits remain uncertain. The user needs a precise way to correct the actual exported geometry |
| 2026-11-08 | Keep the UI self-explanatory with very little instructional text | The owner explicitly dislikes explanation paragraphs. Tapping a mask opens its editor; visible corner handles, zoom, Hide, Reset, Cancel and Save communicate the actions |
