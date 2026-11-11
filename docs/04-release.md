# Releasing

`scripts/release.sh` builds a Release `Feeder.app`, re-signs it with the hardened runtime and packages `dist/Feeder-<version>.dmg` (app plus an Applications shortcut). The version comes from `CFBundleShortVersionString` in `project.yml`.

## Current state
Only an **Apple Development** certificate exists on the Mac, so the DMG is signed but not notarizable. It runs on the build Mac; on other Macs Gatekeeper will refuse it (`spctl` reports "rejected, origin=Apple Development"). A friend can still open it with right-click > Open, then allow it in System Settings > Privacy & Security.

## To distribute properly (needs the paid Apple Developer Program)
1. In Xcode > Settings > Accounts > Manage Certificates, create a **Developer ID Application** certificate.
2. Store notary credentials once (app-specific password from appleid.apple.com):
   ```bash
   xcrun notarytool store-credentials feeder-notary --apple-id <apple id> --team-id V5944XY7RG
   ```
3. Release:
   ```bash
   NOTARY_PROFILE=feeder-notary scripts/release.sh
   ```
   The script picks the Developer ID identity automatically, notarizes, staples and validates the DMG.

## Notes
- Feeder is not sandboxed (event taps need that), so it cannot go on the Mac App Store.
- Accessibility and Input Monitoring grants are tied to the app's signature and path. Installing a differently signed copy, or moving it to /Applications, means granting both again.
- The app icon is an Icon Composer bundle, `Feeder/AppIcon.icon` (a vector keyboard glyph layered on a gradient). Open it in Icon Composer to tweak glass, shadow and dark/tinted variants. Xcode compiles it to `AppIcon.icns` plus `Assets.car` at build time.
