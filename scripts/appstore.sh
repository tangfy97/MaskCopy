#!/bin/zsh
# Builds the App Store version of Maske, for TestFlight and the App Store.
#
#   scripts/appstore.sh                 # signed .ipa in build/appstore
#   scripts/appstore.sh upload          # the same, sent to App Store Connect (then TestFlight)
#   scripts/appstore.sh upload 0.1.0 2  # with a version and build number other than project.yml's
#
# Every upload needs a build number higher than the last one. Signing is automatic: Xcode must be
# signed in to an account in team X933P26489, and it creates the distribution certificate and
# provisioning profile the first time. The app record must exist in App Store Connect first.
set -euo pipefail
cd "$(dirname "$0")/.."

destination=${1:-export}
version=${2:-$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)}
build=${3:-$(sed -nE 's/^ *CURRENT_PROJECT_VERSION: "?([^"]*)"?$/\1/p' project.yml)}
team=${TEAM_ID:-X933P26489}
out=build/appstore
rm -rf "$out" && mkdir -p "$out"

echo "==> Archiving Maske $version ($build)"
xcodegen generate --quiet
xcodebuild -project Maske.xcodeproj -scheme Maske -configuration Release \
  -derivedDataPath build/DerivedData -destination 'generic/platform=iOS' \
  -archivePath "$out/Maske.xcarchive" -allowProvisioningUpdates \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic \
  archive -quiet

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>$destination</string>
    <key>teamID</key>
    <string>$team</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
EOF
echo "==> Exporting ($destination)"
xcodebuild -exportArchive -archivePath "$out/Maske.xcarchive" -exportPath "$out" \
  -exportOptionsPlist "$out/ExportOptions.plist" -allowProvisioningUpdates
ls -l "$out"
