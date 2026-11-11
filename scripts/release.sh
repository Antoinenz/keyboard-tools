#!/bin/bash
# Build a Release Feeder.app, sign it and package dist/Feeder.dmg.
#
#   scripts/release.sh
#
# Environment:
#   SIGN_IDENTITY   codesign identity to use. Default: the first "Developer ID Application"
#                   identity, else the first "Apple Development" identity (works on this
#                   Mac only; other Macs' Gatekeeper will block it).
#   NOTARY_PROFILE  name of a notarytool keychain profile. When set (and the identity is a
#                   Developer ID), the DMG is notarized and stapled.
#                   Create one with:
#                     xcrun notarytool store-credentials <name> --apple-id <id> --team-id <team>
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME=Feeder
BUILD_DIR=build/release
DIST=dist

IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)
fi
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
fi
[ -n "$IDENTITY" ] || { echo "No code signing identity found" >&2; exit 1; }
DEVELOPER_ID=false
case "$IDENTITY" in "Developer ID Application"*) DEVELOPER_ID=true ;; esac
echo "==> Signing with: $IDENTITY"
$DEVELOPER_ID || echo "    (not a Developer ID: the DMG will only run cleanly on this Mac)"

echo "==> Building Release"
xcodegen generate >/dev/null
xcodebuild -project Feeder.xcodeproj -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" build | tail -1

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

echo "==> Re-signing with hardened runtime"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Creating DMG"
rm -rf "$DIST/staging" "$DIST/$APP_NAME-$VERSION.dmg"
mkdir -p "$DIST/staging"
cp -R "$APP" "$DIST/staging/"
ln -s /Applications "$DIST/staging/Applications"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST/staging" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DIST/staging"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"

if $DEVELOPER_ID && [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> Notarizing (this can take a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
else
  echo "==> Skipping notarization (needs a Developer ID identity and NOTARY_PROFILE)"
fi

hdiutil verify "$DMG" | tail -1
echo "==> Done: $DMG"
