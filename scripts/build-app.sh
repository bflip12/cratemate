#!/usr/bin/env bash
# Builds build/CrateMate.app with the Swift Command Line Tools (no Xcode needed).
# Usage: scripts/build-app.sh [--install]   (--install copies it to /Applications)
# Signs ad-hoc unless CODESIGN_IDENTITY names a Developer ID certificate.
set -euo pipefail
cd "$(dirname "$0")/.."

# Universal binary, so it runs on Apple silicon and Intel Macs
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
APP=build/CrateMate.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release "${ARCHS[@]}" --show-bin-path)/CrateMate" "$APP/Contents/MacOS/CrateMate"
# SwiftPM stamps the binary with the deployment target as its SDK version (14.0), which makes
# macOS run it in compatibility mode with the old window chrome. Stamp the real SDK version.
vtool -set-build-version macos 14.0 "$(xcrun --show-sdk-version)" -replace \
  -output "$APP/Contents/MacOS/CrateMate" "$APP/Contents/MacOS/CrateMate"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/" && \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"

# Ad-hoc signature by default: free, and lets macOS remember the Apple Music permission between
# launches. A Developer ID build also gets the hardened runtime and a timestamp, for notarization.
IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  rm -rf /Applications/CrateMate.app
  cp -R "$APP" /Applications/
  echo "Installed /Applications/CrateMate.app"
fi
