#!/bin/zsh
# Unit tests, then the engine against the synthetic documents (fails if a sensitive field is left visible).
set -e
cd "$(dirname "$0")/.."

# The committed project must be the public one: MaskCopy Pro is private (docs/OPEN_CORE.md).
if grep -qE "MaskCopyPro|-DMASKCOPY_PRO" Maske.xcodeproj/project.pbxproj; then
    echo "Maske.xcodeproj includes MaskCopy Pro. Run scripts/pro.sh off."
    exit 1
fi

swift test --quiet
swift build --quiet
.build/debug/maske fixtures Fixtures/synthetic
.build/debug/maske eval Fixtures/synthetic
