# Native usability and visual restraint

The owner requested an app-wide improvement in flow, Nordic simplicity and usability, and explicitly dislikes explanation paragraphs. Continue the existing SwiftUI app and offline Vision engine. Keep the icon and document renderer's masking behaviour.

Three directions were considered: refining the existing large-brand landing screen, building a more editorial custom interface, and making a quiet native document tool. Choose the third: less decorative chrome, system typography, flat source/input rows, one restrained accent and familiar controls. Do not add a variation selector or a new dependency.

The primary journey is Home → import/scan → Review → optional corner adjustment → Share → system share sheet. Home shows sources immediately. Review prioritises the document and puts bulk controls in a menu. Share has two short labelled inputs and an inspectable preview. Loading and failure recovery belong to the same journey, rather than a separate explanatory layer.

Fix the state defects alongside the visual work: background import decoding, cancellable recognition with generation checks, revision-bound previews, and explicit Share-only file creation. Unique export directories keep cancellation of one attempt from deleting another. No data collection or networking is introduced; update PRIVACY with the changed temporary-file lifecycle.

Verification includes the unchanged core suite, delayed-import/read regression tests, file-ownership tests, actual keyboard entry, menu toggles, drawing, zoom/pan/corner editing, preview inspection and system share-sheet presentation. Save baseline and final screenshots locally and inspect compact, dark and enlarged-text states. Record limitations in AUDIT and KNOWN_ISSUES; no frame-rate or on-device performance claim without measurement.
