# Releasing

`scripts/release.sh` builds a Release `Feeder.app`, re-signs it with the hardened runtime and packages `dist/Feeder-<version>.dmg` (app plus an Applications shortcut). The version comes from `CFBundleShortVersionString` in `project.yml`.

## Local install (the plan for now)
The app is for local use, so skip notarization and run:
```bash
scripts/install.sh
```
It builds, signs with the Apple Development identity, copies to `/Applications` and launches. Grant Accessibility and Input Monitoring once for that copy, then "Launch at login" in Settings works. Rerun it to update; the grants survive because the identity and path stay the same.

## Publishing a GitHub release
```bash
scripts/release.sh                        # builds dist/Feeder-<version>.dmg
git tag v<version> && git push --tags
gh release create v<version> dist/Feeder-<version>.dmg --title "Feeder <version>" --notes-file <notes>
```
Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `project.yml` first. Release assets on a private repo are only downloadable by collaborators; the repo has to be public for anyone else to get the DMG.

## Current state
Only an **Apple Development** certificate exists on the Mac, so the DMG is signed but not notarizable. It runs on the build Mac; on other Macs Gatekeeper blocks it at first (`spctl` reports "rejected, origin=Apple Development"). Users open System Settings > Privacy & Security and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Feeder.app`. This flow is documented in the README; it has not been tried on a second Mac.

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
