#!/bin/zsh
# Builds Maske for an iPhone, signed with the team's development certificate, then installs
# and opens it on the connected iPhone (USB, or the same Wi-Fi once paired in Xcode).
#
#   scripts/device.sh              the first connected iPhone
#   scripts/device.sh <UDID|name>  a particular one
#   scripts/device.sh --build-only check that signing works without a phone
#
# The iPhone needs Developer Mode on (Settings ▸ Privacy & Security ▸ Developer Mode).
set -e
cd "$(dirname "$0")/.."

team=${TEAM_ID:-X933P26489}
xcodegen generate --quiet
xcodebuild -project Maske.xcodeproj -scheme Maske -configuration Debug \
    -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates \
    -quiet build
app=build/DerivedData/Build/Products/Debug-iphoneos/Maske.app
codesign --verify --strict "$app"
echo "Signed $app for team $team"
[[ "$1" == "--build-only" ]] && exit 0

device="$1"
if [[ -z "$device" ]]; then
    json=$(mktemp)
    xcrun devicectl list devices --json-output "$json" >/dev/null
    device=$(python3 -I -c '
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("platform") == "iOS" and conn.get("pairingState") == "paired":
        print(d["identifier"]); break
' "$json")
    rm -f "$json"
fi
if [[ -z "$device" ]]; then
    echo "No paired iPhone found. Connect it with a cable, unlock it and tap Trust, then run this again."
    exit 1
fi

xcrun devicectl device install app --device "$device" "$app"
xcrun devicectl device process launch --device "$device" com.feiyangtang.Maske
echo "Maske is open on the iPhone"
