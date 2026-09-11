# Publishing BrowBro on the Mac App Store

The DMG + Homebrew + Sparkle channel is unchanged. This is a second binary of the
same app (`cloud.tiagomoraes.browbro`) built from the `BrowBroMAS` target: App Sandbox on,
Sparkle off, payment links off. Guideline [2.4.5](https://developer.apple.com/app-store/review/guidelines/)
is the rulebook.

## What the MAS target changes

| | `BrowBro` (DMG / Homebrew) | `BrowBroMAS` |
|---|---|---|
| Scheme | `BrowBro` | `BrowBroMAS` |
| Sparkle | linked (`-D SPARKLE`) | **not linked** (`-D APPSTORE`) |
| Sandbox | off | on (`packaging/mas/BrowBro.entitlements`) |
| Chrome folder | TCC + real-home path | NSOpenPanel + security-scoped bookmark |
| Flagged launches (profile / private window) | `Process()` of the browser binary (ADR-0001) | `NSWorkspace.openApplication` with `OpenConfiguration.arguments` |
| Updates UI | Settings + menu item | omitted — the store updates the app |
| Ko-fi / Sponsors | Settings | omitted (guideline 3.1.1) |
| Info.plist | `Resources/Info.plist` | `Resources/Info-MAS.plist` (no `SUFeedURL`) |

Same bundle id, same `PRODUCT_NAME`. Do **not** install a MAS build over
`/Applications/BrowBro.app` — that replaces the daily Sparkle app and resets TCC.

## Local sandbox test

```sh
packaging/mas/build-mas.sh            # Debug → build/mas/Build/Products/Debug/BrowBro.app
open -a "$PWD/build/mas/Build/Products/Debug/BrowBro.app" "https://example.com/mas-test"
```

The script refuses to succeed if Sparkle is in the bundle, if `SUFeedURL` leaked
into Info.plist, or if the App Sandbox entitlement is missing.

Prove the three sandbox-sensitive paths before submitting:

1. **Default browser** — Settings → Set as default, click a link in Notes.
2. **Chrome profiles** — Settings → Grant access… and pick
   `~/Library/Application Support/Google/Chrome`. Quit and relaunch: the grant
   must survive (bookmark). Profiles should appear in the picker.
3. **Profile / private window** — pick a Chrome profile and a Private Window
   variant. The flags have to arrive; a sandbox-blocked `Process()` used to fail
   silently here.

`/usr/bin/log show --last 5m --info --predicate 'subsystem == "cloud.tiagomoraes.browbro"'`
logs picker decisions and `category == "launch"` workspace launches.

## One-time App Store Connect setup

You already have the Apple Developer Program (team `QD5A8CZK76`) and a Developer
ID for notarization. The store needs extra pieces the DMG never used:

1. Sign the **Paid Apps Agreement** in App Store Connect (even for a free app).
2. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list):
   an App ID for `cloud.tiagomoraes.browbro` with Mac enabled. Automatic signing on
   `BrowBroMAS` will create this on first Archive if it doesn't exist.
3. An **Apple Distribution** certificate (Xcode → Settings → Accounts → Manage
   Certificates → + → Apple Distribution). Distinct from Developer ID.
4. App Store Connect → My Apps → (+) → New Mac App:
   - Bundle ID `cloud.tiagomoraes.browbro`
   - SKU e.g. `browbro` (immutable)
   - Category: *Utilities* (matches `LSApplicationCategoryType`)

## Product page (required to submit)

- **Privacy policy URL** — `https://browbro.tiagomoraes.cloud/privacy` (`site/privacy/`).
- **Support URL** — `https://browbro.tiagomoraes.cloud` or the GitHub repo.
- **App Privacy** questionnaire — BrowBro does not collect data; Chrome profile
  names never leave the device. Answer accordingly.
- **Age rating** questionnaire.
- **Screenshots** — eight English marketing frames at 2560×1600 (16:10, no
  alpha). Source `packaging/mas/screenshots/mock.html`; render with
  `packaging/mas/render-screenshots.sh`. Fictional UI only (Work / Personal /
  Design / Client, Safari, Firefox, Edge) — never a capture of a real machine.
  See `packaging/mas/listing.md` for upload order.
- **App preview** (optional) — `packaging/mas/previews/01-every-link.mp4`, built
  by `packaging/mas/render-preview.sh`. macOS previews are **1920×1080 (16:9)**,
  15–30s, ≤30fps — a different shape from the screenshots, and Connect rejects
  2560×1600 here.
- **App Store icon** — 1024×1024 PNG, no transparency. The bundled `.icns` is
  not this file; export a square fill (Apple applies the squircle).
- **Review notes** — BrowBro is not a web browser. It registers as the default
  http(s) handler and forwards the URL to the user's installed browsers. To
  test: Settings → Set as default → click a link in Mail or Notes → pick Chrome.
  Chrome profiles need the Grant access… open panel.

## Archive and upload

From Xcode (recommended the first time):

1. Scheme `BrowBroMAS`, destination **Any Mac** (or My Mac).
2. Product → Archive.
3. Organizer → Distribute App → App Store Connect → Upload.
   Automatic signing on this target picks Apple Distribution and a Mac App Store
   Connect profile.

From the command line, after the app record exists:

```sh
xcodegen generate
xcodebuild -project BrowBro.xcodeproj -scheme BrowBroMAS -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath build/BrowBro.xcarchive archive

xcodebuild -exportArchive \
  -archivePath build/BrowBro.xcarchive \
  -exportPath build/mas-export \
  -exportOptionsPlist packaging/mas/ExportOptions.plist
```

That writes a `.pkg`. Upload it with Transporter, or set `destination` in
`ExportOptions.plist` to `upload`.

TestFlight for Mac is available once the build is processed — use it before
submitting for review.

### Upload validation, before review

Connect validates the bundle at upload, long before a human sees it. Two rejections
have actually happened here:

- **ITMS-90301** — *"Apple is not currently accepting applications built with this
  version of Xcode."* A beta or Release Candidate Xcode cannot upload, even though it
  builds and archives fine. Check `xcodebuild -version`; the toolchain has to be a
  released Xcode (26 or later, per
  [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)).
  Keep a shipped Xcode alongside the seed and select it with
  `DEVELOPER_DIR=/Applications/Xcode-26.app/Contents/Developer`.
- **ITMS-90243** — every `CFBundleDocumentTypes` entry needs `CFBundleTypeName`
  (and Connect warns separately about a missing `LSHandlerRank`). Both are in
  `Resources/Info-MAS.plist` now, and `build-mas.sh` fails without the first.

A failed upload does not burn the build number: the same `CURRENT_PROJECT_VERSION`
can be re-uploaded once the cause is fixed.

## Dual channel

Keep shipping the notarized DMG as today (`packaging/notarize/notarize-release.sh`,
[NOTARIZING.md](NOTARIZING.md), [UPDATES.md](UPDATES.md)). Users pick a channel:

- **DMG / Homebrew** — Sparkle updates, Developer ID signature.
- **Mac App Store** — store updates, Apple Distribution signature.

Switching channels resets TCC (different signing identity) and does not carry
UserDefaults: the sandboxed app stores prefs in its container,
`~/Library/Containers/cloud.tiagomoraes.browbro/`, not `~/Library/Preferences/cloud.tiagomoraes.browbro.plist`.

Do not create a second bundle id. Two products, two TCC grants, two profile lists.

## First-review expectancies

A "default browser that doesn't render pages" is an established Mac App Store
category (Velja, Choosy). Still write the review notes as if the reviewer has
never seen one. Common bounce-backs:

- Sparkle / `SUFeedURL` still in the bundle → this target is built so that can't happen.
- Chrome profiles empty because they skipped Grant access… → spell out the panel in the notes.
- Profile / incognito opens the wrong window → that's the `NSWorkspace` flags path; verify it locally first.
- Ko-fi / Sponsors in the binary → omitted from `BrowBroMAS`.
