#!/bin/zsh
# Development build: regenerates the Xcode project from project.yml and builds the app
# for the iOS Simulator into build/MaskCopy.app.
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Maske.xcodeproj -scheme Maske -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/DerivedData -quiet build

rm -rf build/MaskCopy.app
cp -R build/DerivedData/Build/Products/Debug-iphonesimulator/MaskCopy.app build/
echo "Built build/MaskCopy.app"
