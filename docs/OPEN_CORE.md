# Open core

MaskCopy is open core. Everything that decides whether your document is safe to share is in this
repository, under the Apache License 2.0: recognition, masking, rendering, the watermark, export and
the free app. **MaskCopy Pro**, a one-time in-app purchase, adds paid workflows. Its code is
proprietary and lives in a separate, private repository.

## What is open and what is Pro

| Open (this repository) | Pro (private) |
|---|---|
| The engine (`Sources/MaskeCore`): MRZ, national numbers with check digits, labels, addresses, and the detectors Pro relies on (account and card numbers and the like) | Workflows for other documents (payslips, bank statements, bills) |
| Masks painted into the pixels, the watermark, JPG/PDF without metadata | Application packs: several documents in one watermarked PDF |
| The free app: scan, check masks, watermark, share | A copy register and delete reminders, kept on the iPhone |
| Tests and synthetic documents | The purchase screen and StoreKit code |

A detector that finds something sensitive always goes in the open engine, so anyone can check what
MaskCopy hides. Pro only adds ways of using it.

**The free app copies official identity documents only:** passports, national ID cards, residence
permits and driving licences. The engine marks a page as another document (`PageAnalysis.isOtherDocument`)
only on positive evidence: a payslip, bank statement, bill or tax title, or a tall page with an
account or card number and nothing of an identity document. An identity document that is read badly
is never refused. The free app refuses other documents (`ProAccess.otherDocuments` in ProSeam.swift).
Pro unlocks them; until Pro can be bought, the refusal does not mention it.

## How the App Store build includes Pro

- `project.yml` includes `../MaskCopyPro/project.pro.yml` only when the environment variable
  `MASKCOPY_PRO` is set. That file adds Pro's sources to the app target and defines `MASKCOPY_PRO`
  for Swift.
- [ProSeam.swift](../Sources/MaskeApp/ProSeam.swift) is the only place the public app refers to Pro.
  Without the flag it adds nothing.
- `scripts/appstore.sh` sets the flag when the private repository sits next to this one, and
  regenerates the public project when it finishes.
- `scripts/pro.sh on|off` switches a local checkout between the two.

Without the private repository, this repository builds and runs the complete free app.

## Keeping Pro out of this repository

- The committed `Maske.xcodeproj` is always the public one. `scripts/check.sh` fails if it refers
  to Pro.
- The pre-commit hook in `.githooks` refuses a staged Pro path or a project generated with Pro.
  Enable it once per clone with `git config core.hooksPath .githooks`.
- Plans, prices and other business notes for Pro stay in the private repository.

## Purchases and privacy

The purchase goes through Apple's StoreKit. Apple verifies the transaction on the device.
MaskCopy has no server and no account, and it never sees payment details. Pro features stay
offline like the rest of the app. PRIVACY.md is updated in the release that first ships a Pro
feature.
