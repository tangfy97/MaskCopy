#!/bin/zsh
# Simulator UI regression, using generated synthetic documents only.
set -e
cd "$(dirname "$0")/.."

simulator="${MASKE_SIMULATOR_ID:-$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; print(next((d["udid"] for group in json.load(sys.stdin)["devices"].values() for d in group if d["state"] == "Booted"), ""))')}"
if [[ -z "$simulator" ]]; then
    echo "Boot an iOS Simulator first, or set MASKE_SIMULATOR_ID."
    exit 2
fi

swift run --quiet maske fixtures Fixtures/synthetic
xcodegen generate --quiet
mkdir -p build
result_dir="$(mktemp -d "$PWD/build/UITest.XXXXXX")"
xcodebuild -project Maske.xcodeproj -scheme Maske -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator" \
    -derivedDataPath build/UITestDerivedData \
    -resultBundlePath "$result_dir/result.xcresult" -quiet test
echo "UI result: $result_dir/result.xcresult"
