# Releasing Maske

## Every build

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` (every upload needs a higher build number), and `MARKETING_VERSION` for a new version. Add it to `CHANGELOG.md`.
2. Check everything:
   ```bash
   scripts/check.sh
   ```
3. Build, sign and upload:
   ```bash
   scripts/appstore.sh upload
   ```
   Apple processes the build in 5–15 minutes. It then goes automatically to the internal TestFlight group **TangSpark**.

Build 4 upload completed at 01:49 Amsterdam time on 8 November. Xcode reported `Upload succeeded` and `Uploaded package is processing`. This confirms transfer, not Ready to Test or installation availability. Its signed archive was verified as 0.1.0 (4), with a 1024 px AppIcon and no specimen images or UI test bundle. The app icon artwork was not changed.

Run `scripts/ui-check.sh` on a booted Simulator for the editor/export regression before a UI release. The build 4 checks are recorded in KNOWN_ISSUES; the iOS Simulator still misses the photo and MRZ of one synthetic Chinese passport turned 90°, while the Mac passes that case.

## One-time setup

| What | Status |
|---|---|
| Distribution signing | Cloud-managed by Xcode (team X933P26489) |
| Bundle ID `com.feiyangtang.Maske` | Registered by the first archive (`-allowProvisioningUpdates`) |
| App record | Created 7 November 2026, Apple ID 6832059753 |
| TestFlight | Internal group TangSpark, automatic distribution on, Feiyang Tang added |
| Builds uploaded | 0.1.0 (1) and (2), 7 November; (3) and (4), 8 November 2026 |
| Developer Program License Agreement | An update was waiting for the account holder to accept (needed before App Review; not needed for internal TestFlight) |
| Export compliance | `ITSAppUsesNonExemptEncryption` is NO in `project.yml` |

## App Store Connect

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Maske: Privacy-First ID Copy |
| Bundle ID | `com.feiyangtang.Maske` |
| SKU | `maske-ios` |
| Primary language | English (U.S.) |
| User access | Full Access |
| Category | Utilities (to set) |
| Price | Free (to set) |
| App Privacy | Data Not Collected (to set) |
| Age rating | 4+ (to set) |

Before submitting for review: screenshots, description, support and privacy URLs on tang-spark.no, and the localizations.

## Notes for App Review (draft)

Maske reads identity documents only on the device, with Apple's Vision framework, to suggest which parts to hide. It has no networking code and keeps nothing after sharing. To test without a document, use any of the synthetic images made by `maske fixtures` (made-up people) from the Photos picker.
