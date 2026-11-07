# Contributing to Maske

Thanks for helping. Bug reports, new countries, translations and small, focused pull requests are all welcome.

## Building

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh   # the app for the iOS Simulator
scripts/check.sh   # unit tests and the synthetic documents; must pass
```

Edit `project.yml`, not the `.xcodeproj`. How the engine works and how to add a country: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Pull requests

- Keep one change per pull request, and describe how you tested it.
- `scripts/check.sh` must pass: no sensitive field in the synthetic documents may be left visible.
- **Never add a real person's document**, masked or not, to the repository, an issue or a pull request. Add a synthetic one to `Sources/maske/Fixtures.swift` with made-up details and valid check digits.
- Maske stays offline: no networking, analytics or third-party code. Text, faces and barcodes are read only with Apple's Vision framework.
- If a change affects what Maske keeps or shares, update [PRIVACY.md](PRIVACY.md) in the same pull request.
- Maske uses standard iOS controls and its small palette in `Theme.swift`. Please don't add custom styling.

By contributing you agree that your work is licensed under the [Apache License 2.0](LICENSE).
