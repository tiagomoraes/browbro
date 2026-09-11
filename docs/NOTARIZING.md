# Signing & notarizing BrowBro

Public releases are signed with an Apple **Developer ID Application** certificate,
built with the **hardened runtime**, and **notarized** by Apple. This document is
the outside-the-store path. The Mac App Store binary is a different target and
a different certificate — see [MAS.md](MAS.md). A notarized,
stapled build opens on first launch with no "unidentified developer" block and no
detour through System Settings — and it's a prerequisite for landing in
homebrew-cask core.

Everything below is already set up on the maintainer's machine; it's written down
so a lost laptop or a second maintainer isn't a research project.

## One-time setup

1. **Enroll** in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/yr).
   The free "Apple Development" certificate used for local builds cannot notarize.
2. **Create a Developer ID Application certificate**
   Xcode, then Settings, then Accounts, then your team, then Manage Certificates,
   then the `+`, then "Developer ID Application". Confirm it's in your login keychain:
   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
   Back it up: export the certificate **and its private key** as a `.p12` from
   Keychain Access. Apple issues a limited number of Developer ID certificates per
   account, and the private key cannot be recovered from Apple.
3. **Store notarization credentials** as a keychain profile named `browbro-notary`
   (the default the release script looks for):
   ```sh
   xcrun notarytool store-credentials browbro-notary \
     --apple-id "you@example.com" \
     --team-id "QD5A8CZK76" \
     --password "APP-SPECIFIC-PASSWORD"
   ```
   Create the app-specific password at [appleid.apple.com](https://appleid.apple.com)
   (Sign-In and Security, then App-Specific Passwords). Alternatively pass an App
   Store Connect API key with `--key` / `--key-id` / `--issuer`.
4. **Install dmgbuild**: `pipx install dmgbuild`. A bare `pip install` fails on a
   Homebrew Python (PEP 668 marks the environment externally managed).

## Build a release DMG

```sh
packaging/notarize/notarize-release.sh build/BrowBro.dmg
```

That's the whole command — the Developer ID is auto-detected from the keychain and
the notary profile defaults to `browbro-notary`. The script builds a universal,
hardened-runtime app, signs Sparkle's nested helpers inside-out, signs the app, wraps
it in the styled DMG (`packaging/dmg/`), signs the disk image, submits it to Apple,
waits, staples the ticket, and then **refuses to succeed** unless Gatekeeper accepts
both the DMG and the app inside it. If it prints `✅`, the download is clean.

To check an already-built DMG by hand:

```sh
spctl -a -t open --context context:primary-signature -vv build/BrowBro.dmg
# -> accepted, source=Notarized Developer ID
```

> **Staple, or it didn't happen.** Notarization succeeding at Apple is not enough:
> an accepted-but-unstapled DMG is indistinguishable from an unsigned one on a
> machine that can't reach Apple, and `stapler validate` is what proves the ticket
> is attached. v0.1.6 was notarized successfully and shipped unsigned anyway,
> because the run was interrupted between the two steps. The script now gates on it.

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
6. Submitting the cask to homebrew-cask core (so the bare `brew install --cask browbro`
   works) needs two things: notarization — now done — and their popularity floor of
   30 stars, forks, or watchers on the repo. At 10 stars that's still the blocker.

## Notes

- **Changing the signing identity is safe for existing installs.** Sparkle accepts
  an update when *either* the EdDSA key matches *or* the Apple code-signing identity
  matches — precisely so identities can rotate. BrowBro keeps the same `SUPublicEDKey`,
  so users on an "Apple Development"-signed build update cleanly to a Developer ID one.
- **It is not free for TCC.** macOS keys privacy grants to the code-signing identity,
  so the first Developer ID build asks again for permission to read other apps' data
  (how BrowBro discovers Chrome profiles). One prompt, once.
- If a future feature scripts another app or needs a hardened-runtime exception,
  add the entitlement to `packaging/notarize/BrowBro.entitlements`.
- `packaging/dmg/build-dmg.sh` builds an unsigned-to-the-world DMG for quick local
  previews. **Never ship its output** — it's the path that produced the blocked
  v0.1.6 download.
