# Native interface and usability audit

8 November 2026. Baseline: c2d3ec3, build 4. Scope: Home, import/loading/recovery, Review, mask controls, corner editor, Share, copy inspector, system share sheet and supported documents. Test documents are generated fixtures only. The masking engine and icon artwork are unchanged.

## Evidence and coverage

Baseline screenshots came from the actual app on iPhone 18 Pro, iOS 27 Simulator. They showed a large branded landing layout, a prominent block of switches below the document, shadowed preview cards, repeated field chrome and a long introductory paragraph in Documents. Screenshots and test result bundles are kept locally under build and /tmp/maske-ux; they are not specimen images or committed assets.

The target direction is documented in DESIGN.md. The offline design search's generic hero/testimonial and neumorphic suggestions did not fit this utility and were rejected. The useful guidance was functional hierarchy, restrained surfaces, native controls, honest progress and recoverable actions. No third-party UI library, font or analytics service is added.

## Findings and changes

### P1: late work could modify a newer or cancelled session

Static evidence: Session.start previously launched recognition without a cancellation or generation check. Delayed results could overwrite pages after the user left or started another document. Import work had the same risk.

Changed: explicit preparing/reading states, background decoding, cancelable tasks and generation checks. Returning Home clears the session. Current Vision work can finish offscreen; later pages are skipped. App regressions deliberately finish an old read/import late and verify that it cannot reopen or replace the current session.

### P1: an outdated preview could remain shareable while details changed

Static evidence: Share previously retained the previous file while an asynchronous replacement was being prepared. Detached results had no final cancellation/revision check. Typing also repeatedly wrote temporary files.

Changed: previews stay in memory and are tied to document, mask and input revisions. Share is enabled only for the current rendered inputs. An explicit Share action creates the JPEG; separate attempts own separate directories. Cancellation discards only its own result. Abandoned temporary copies are cleared on the next session. Regressions cover preview file absence, independent export ownership and startup cleanup; the UI journey checks actual keyboard input and system-sheet presentation.

### P2: decoration and repeated controls competed with the document

Observed in the baseline Home, Review and Share captures. The old homepage had a display-sized brand, mark and slogan. Review repeated its controls in a large switch card. Custom field borders and preview shadows added weight without another task.

Changed: flat source choices, system typography, a cool neutral background and one grey-blue accent. Review uses a smaller context line and native Masks menu. Share uses two flat labelled input rows and one primary action. The image opens a zoomable copy inspector. Explanation paragraphs are omitted.

### P2: small masks and newly drawn rectangles were hard to adjust

Changed: nearest-edge selection within 22 points improves access to short text masks without enlarging the exported polygon. Drawing a mask opens the four-corner editor immediately. Bulk toggles remain available in the native menu. UI regressions exercise menu selection, drawing, scrolling, zoomed corner dragging, Save and Cancel.

### P2: import and failure states lacked a clear recovery path

Changed: photo/file decoding runs away from the main actor, opening and reading states provide immediate feedback, and Cancel remains available during work. Unreadable input returns to a native alert and usable Home. The scanner forwards images into the same import pipeline. Camera hardware and actual iCloud-provider delays still require device checks.

### P2: duplicated accessibility labels and weak secondary text

Observed during the keyboard test: native labelled fields were announced as “Recipient, Recipient”. Removed redundant accessibility labels and kept stable test identifiers. Shared semantic colours replace washed-out custom secondary text.

Calculated token contrasts on their actual semantic backgrounds: light primary 13.33:1, light muted 5.17:1, light action 6.93:1; dark primary 15.46:1, dark muted 8.49:1, dark action 10.09:1. These are selected colour-pair measurements, not a claim of complete accessibility conformance. Native alert dismissal was also adjusted after the first run exposed a state-publication runtime warning; the subsequent run had none.

### P3: supported-document lookup required unnecessary reading and scrolling

Changed: removed the introductory claim of exhaustive field-by-field verification, kept the country/document list and added native country search. Recognition limitations remain in KNOWN_ISSUES rather than a paragraph on the lookup screen.

### P2: maximum accessibility text size compressed horizontal layouts

Observed on a 375 × 667 point iPhone SE Simulator, dark appearance, accessibility-extra-extra-extra-large: document types broke into individual letters, field labels hyphenated beside compressed values, decorative symbols consumed text width and a fixed footer reduced the scrollable source area. The action bar also competed with the keyboard for editing space.

Changed: stack document types, Review context and labelled inputs vertically at accessibility sizes; omit source-row symbols at those sizes and keep zoom symbols compact. Source choices and their footer share a scrollable area. Hide the share action while a field is focused and restore it after keyboard Done; Next moves to Purpose. Scroll the focused row into view on focus changes and after the keyboard opens, respecting Reduce Motion. The keyboard test exercises that actual navigation and checks the field is fully above the keyboard. These changes preserve the user's selected text size.

## Verification status

Baseline captures are kept at `build/UXReview/before/{home,review,share,documents}.png`; final captures use `build/UXReview/after-light/` and `after-compact-ax/`. All are generated documents, kept locally and excluded from Git. The Home, Review, Share, Documents, editor and copy inspector captures were visually inspected. In particular, the final compact keyboard capture shows the Purpose label and complete focused input above the keyboard.

- `scripts/check.sh`: 14 core tests passed; 43/43 synthetic documents, 121/121 sensitive fields at the existing ≥98% coverage threshold, 96/96 preserved fields. Mean mask precision 0.96, worst 0.75. Recognition code is unchanged in this release; these numbers do not establish complete masking on real photos.
- iPhone 18 Pro, iOS 27 Simulator, light appearance and normal text: 11/11 app/UI tests passed in `/tmp/maske-ux/Release5Light.xcresult` (five app-state/file tests and six UI tests). After the final focus-scroll fix, both affected Share journeys passed again in `FocusLight.xcresult`.
- iPhone SE (3rd generation), 375 × 667 points, iOS 27 Simulator, dark appearance and maximum accessibility text: 4/4 selected journeys passed in `Release5CompactAX.xcresult` (Home/search, Review/preview, keyboard/system sharing and corner editing). The final keyboard visibility assertion and share journey passed again in `FocusCompactAX.xcresult` after the focus-scroll fix. Normal-size compact Home/Share were also checked earlier.
- These final result bundles contain no runtime warnings. `git diff --check` passed. Earlier failures exposed actual large-text layout issues and inadequate test assumptions about virtualised list rows and asynchronous share-sheet dismissal; they were corrected and rerun.
- The signed release archive passed strict signature verification as 0.1.0 (5), includes the unchanged 1024 × 1024 AppIcon, and contains no fixture images or test bundles. App Store Connect accepted the upload at 11:54 Amsterdam time on 8 November and reported Processing. Ready to Test remains unconfirmed.

Still unverified: physical camera capture, real-device frame pacing and recognition time, manual VoiceOver use, Switch Control and Full Keyboard Access. Reduce Motion is respected by the drawing-mode transition and standard navigation remains native; a system-setting device check is still needed. No business-impact, frame-rate or full-conformance score is claimed.
