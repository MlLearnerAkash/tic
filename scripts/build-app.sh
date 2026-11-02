#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building Tic…"
swift build -c release

APP="build/Tic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/Tic" "$APP/Contents/MacOS/Tic"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || {
    echo "Ad-hoc signing failed; the app may still run locally."
}

echo ""
echo "Built: $(pwd)/$APP"
echo "Launch: open \"$(pwd)/$APP\""
echo "Install: cp -R \"$(pwd)/$APP\" /Applications/"
