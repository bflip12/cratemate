#!/usr/bin/env bash
# Packs build/CrateMate.app into a drag-to-Applications disk image, using only hdiutil.
# Usage: scripts/make-dmg.sh   (run scripts/build-app.sh first)
# Writes build/CrateMate-<version>.dmg and a copy at build/CrateMate.dmg, which is the name the
# website's "latest" download link points at. Signs with CODESIGN_IDENTITY if it's set.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/CrateMate.app
[ -d "$APP" ] || { echo "No $APP. Run scripts/build-app.sh first." >&2; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/CrateMate-$VERSION.dmg"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/CrateMate.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG" build/CrateMate.dmg
hdiutil create -volname "CrateMate $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO \
  -imagekey zlib-level=9 -ov "$DMG" >/dev/null

# A Developer ID signature on the image itself lets it be notarized and stapled too
if [ -n "${CODESIGN_IDENTITY:-}" ] && [ "$CODESIGN_IDENTITY" != "-" ]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"
fi
cp "$DMG" build/CrateMate.dmg
echo "Built $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
