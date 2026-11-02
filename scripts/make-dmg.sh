#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Tic.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

if [ ! -d "$APP" ]; then
    echo "build/Tic.app not found. Run ./scripts/build-app.sh first."
    exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

OUT="build/Tic-${VERSION}.dmg"
rm -f "$OUT"

hdiutil create \
    -volname "Tic" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$OUT" >/dev/null

shasum -a 256 "$OUT" | tee "$OUT.sha256"
echo ""
echo "Built: $(pwd)/$OUT"
