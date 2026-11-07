#!/bin/zsh
# Unit tests, then the engine against the synthetic documents (fails if a sensitive field is left visible).
set -e
cd "$(dirname "$0")/.."

swift test --quiet
swift build --quiet
.build/debug/maske fixtures Fixtures/synthetic
.build/debug/maske eval Fixtures/synthetic
