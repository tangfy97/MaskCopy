<p align="center"><img src="Design/AppIcon-1024.png" width="128" height="128" alt="Maske icon: a card with one line blacked out"></p>

# Maske

An iPhone app for sharing a copy of your passport, ID card or driving licence without giving away more than the other side needs. Scan the document, check what Maske covers, say who the copy is for, and share. *Maske* is Norwegian for "mask".

- Works with documents from any country: passports through the machine-readable zone, and European ID cards, residence permits and driving licences checked field by field, along with documents from the US, Canada, Mexico, Australia, New Zealand, China, Hong Kong, Taiwan, Japan, South Korea, Singapore and Malaysia ([full list](Sources/MaskeCore/Countries.swift))
- Covers the machine-readable zone, personal numbers (BSN, fødselsnummer, PESEL, codice fiscale, 身份证号, NRIC, MyKad and about 40 more, each checked by its check digit), document and licence numbers, the card access number, addresses, barcodes and the photo
- Every box can be shown or hidden with a tap, and you can draw your own
- The copy has the recipient, the purpose and the date written across it, the masks painted into the pixels (never blurred), a smaller size and no metadata
- Everything happens on the iPhone with Apple's Vision framework. No network code, no accounts, no analytics, no third-party code, and nothing is kept after you share ([privacy policy](PRIVACY.md))

**Status:** prototype 0.1.0, in TestFlight (build 2). Not yet on the App Store. What still goes wrong: [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md). What comes next: [docs/ROADMAP.md](docs/ROADMAP.md).

**Working on Maske with a coding agent?** Start with [AGENTS.md](AGENTS.md): the rules, the map of the code, how to test, and what was learned so far.

## Build

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh      # the app for the iOS Simulator, in build/Maske.app
scripts/check.sh      # unit tests, then the engine against the synthetic documents
scripts/device.sh     # signed build, installed and opened on the connected iPhone (Developer Mode on)
```

`project.yml` is the source of truth for the Xcode project; edit it rather than the `.xcodeproj`, then run `xcodegen generate`. The engine lives in `Sources/MaskeCore` and is shared by the app and by `maske`, a command-line tool in the Swift package:

| Command | What it does |
|---|---|
| `maske fixtures Fixtures/synthetic` | Draws the synthetic documents (made-up people, valid check digits) and the boxes that must be hidden or kept |
| `maske eval Fixtures/synthetic` | Runs the engine on them and reports what was missed; masked copies go to `Fixtures/synthetic/out` |
| `maske analyze <image>` | Prints what the engine finds on one image |
| `scripts/icon.swift` | Renders the app icon |

In the simulator, which has no camera, launch with `-MaskeFixture /path/to/front.png,/path/to/back.png` to open documents directly.

| Document | About |
|---|---|
| [AGENTS.md](AGENTS.md) | Handoff for coding agents: rules, code map, commands, gotchas, release details |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | How the engine works and how it is tested |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Open problems, what was ruled out, what to try next |
| [docs/ROADMAP.md](docs/ROADMAP.md) | What to do next, in order |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Why things are the way they are |
| [docs/SPECIMENS.md](docs/SPECIMENS.md) | Test images: synthetic documents, PRADO, Wikimedia Commons |
| [docs/APP_STORE.md](docs/APP_STORE.md) | Releasing, App Store Connect and TestFlight |
| [docs/user-journey.md](docs/user-journey.md) | The user journey (in Chinese) |

## License

Copyright © 2026 TangSpark. Released under the [Apache License 2.0](LICENSE). Contributions: [CONTRIBUTING.md](CONTRIBUTING.md). Security: [SECURITY.md](SECURITY.md).
