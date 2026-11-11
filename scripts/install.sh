#!/bin/bash
# Build a Release Feeder and install it to /Applications (for local use).
# Grant Accessibility and Input Monitoring once for this copy; it keeps them across rebuilds
# because it is always signed with the same identity and lives at the same path.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
[ -n "$IDENTITY" ] || { echo "No Apple Development identity found" >&2; exit 1; }

xcodegen generate >/dev/null
xcodebuild -project Feeder.xcodeproj -scheme Feeder -configuration Release \
  -derivedDataPath build/release build | tail -1
APP=build/release/Build/Products/Release/Feeder.app
codesign --force --options runtime --sign "$IDENTITY" "$APP"

pkill -x Feeder || true
sleep 1
rm -rf /Applications/Feeder.app
cp -R "$APP" /Applications/Feeder.app
open /Applications/Feeder.app
echo "Installed /Applications/Feeder.app"
