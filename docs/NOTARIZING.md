# Notarizing BrowBro

Notarization is Apple's automated malware check. A notarized, stapled build opens
with no "Open Anyway" detour, and it's a prerequisite for landing in homebrew-cask
core. It requires a **paid Apple Developer Program** membership (the free "Apple
Development" certificate used for local builds cannot notarize).

## One-time setup

1. **Enroll** in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/yr).
2. **Create a Developer ID Application certificate**
   Xcode, then Settings, then Accounts, then your team, then Manage Certificates,
   then the `+`, then "Developer ID Application". Confirm it's in your login keychain:
   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
3. **Store notarization credentials** as a keychain profile:
   ```sh
   xcrun notarytool store-credentials browbro-notary \
     --apple-id "you@example.com" \
     --team-id "YOURTEAMID" \
     --password "APP-SPECIFIC-PASSWORD"
   ```
   Create the app-specific password at [appleid.apple.com](https://appleid.apple.com)
   (Sign-In and Security, then App-Specific Passwords). Alternatively pass an App
   Store Connect API key with `--key` / `--key-id` / `--issuer`.

## Build a notarized DMG

```sh
pip install dmgbuild
DEVELOPER_ID="Developer ID Application: Your Name (YOURTEAMID)" \
NOTARY_PROFILE="browbro-notary" \
packaging/notarize/notarize-release.sh build/BrowBro.dmg
```

The script builds a universal, hardened-runtime, Developer-ID-signed app, wraps it
in the styled DMG (`packaging/dmg/`), submits it to Apple, waits, and staples the
ticket. Verify:

```sh
spctl -a -t open --context context:primary-signature -vv build/BrowBro.dmg   # -> accepted
```

## Release it

1. Bump `MARKETING_VERSION` **and** `CURRENT_PROJECT_VERSION` in `project.yml`
   (the build number must strictly increase for Sparkle — see
   [UPDATES.md](UPDATES.md)), and update `CHANGELOG.md`.
2. Cut `release/x.y.z`, PR into `main`, tag `vX.Y.Z` (see CONTRIBUTING.md).
3. Upload the notarized **`BrowBro.dmg`** as the release asset (keep the exact
   name so `releases/latest/download/BrowBro.dmg` and the website keep working).
4. Publish the Sparkle update feed so existing installs can self-update: run
   `packaging/appcast/generate-item.sh build/BrowBro.dmg`, paste the printed
   `<item>` at the top of the `<channel>` in `site/appcast.xml`, and merge it to
   `main` (Pages redeploys the feed). Full walkthrough in [UPDATES.md](UPDATES.md).
5. Update the cask in the [homebrew-browbro tap](https://github.com/tiagomoraes/homebrew-browbro):
   bump `version` and `sha256`.
6. Once notarized and reasonably popular, the cask can be submitted to
   homebrew-cask core so the bare `brew install --cask browbro` works.

## Notes

- If a future feature scripts another app or needs a hardened-runtime exception,
  add the entitlement to `packaging/notarize/BrowBro.entitlements`.
- The default (unsigned-to-the-world) `packaging/dmg/build-dmg.sh` still works for
  quick local/preview builds; this pipeline is only for public, notarized releases.
