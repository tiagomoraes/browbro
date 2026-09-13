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

## Uploading from CI

[`.github/workflows/app-store.yml`](../.github/workflows/app-store.yml) archives
`BrowBroMAS` on a `macos-26` runner, uploads it, attaches it to the version,
pushes the product page, and submits it for review.

It was written because of the trap above, when a maintainer on a macOS seed had
*no* usable toolchain: the only Xcode that ran on a prerelease macOS was the one
Connect refuses, and an Xcode old enough to be accepted wouldn't launch there
([Apple DTS](https://developer.apple.com/forums/thread/831716)). **That is no
longer the constraint** — 1.0 (8) and (9) were both uploaded by hand from a
maintainer's Mac on 2026-09-13, once Xcode 27.0 shipped. CI stays the default
because the runner is a known-good production macOS, and because it is the only
place a release trigger can reach.

**This does publish.** A published, non-prerelease GitHub Release now goes all the
way to App Review without anyone opening App Store Connect. Cut a prerelease, or
dispatch with `submit=false`, when that is not what you want. The DMG channel is
untouched — it still needs the Developer ID identity and the EdDSA update key,
which stay on the maintainer's machine.

### What it decides for you

**The build number comes from Connect, not the repo.** A build number may only be
used once per version, and Connect counts uploads that were never shipped — 1.0
reached build 9 through two by-hand uploads that no counter here ever saw. The
workflow asks for the highest build against `MARKETING_VERSION` and archives one
past it. `CURRENT_PROJECT_VERSION` in `project.yml` stays as the floor for a local
archive, and `-f build_number=N` still overrides everything.

**The product page comes from `packaging/mas/listing.md`.** `listing-to-metadata.py`
projects its fenced blocks into the `fastlane/metadata/` tree that `deliver`
uploads, so the copy is written and reviewed in one place and never transcribed
twice. The generated tree is gitignored: edit `listing.md`. A missing section fails
the release instead of shipping a blank field.

App Review *contact* details — name, phone, email — are deliberately **not** in
that tree. This repository is public; they live only in Connect, and `deliver`
leaves them alone.

**Screenshots are opt-in** (`-f screenshots=true`). They change about once a year,
and replacing them means deleting what is live first.

### Secrets, once

Both certificates go in **one** `.p12`: Apple Distribution signs the app, 3rd Party
Mac Developer Installer signs the `.pkg` around it. Keychain Access → select both
identities (⌘-click) → right-click → *Export 2 items…* → `.p12` with a password.

The API key comes from App Store Connect → Users and Access → Integrations → App
Store Connect API → generate a key with the **App Manager** role. The `.p8`
downloads exactly once; the Key ID and Issuer ID are on that page.

The signing is manual, so the provisioning profile ships too — and it has to be a
**manually created** one. The profiles Xcode leaves in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles/` after an Archive are
Xcode-managed, and manual signing refuses them outright: *"is Xcode managed, but
signing settings require a manually managed profile."* Create one at
[Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/profiles/list)
→ Profiles → **+** → **Mac App Store Connect** → App ID `cloud.tiagomoraes.browbro`
→ the Apple Distribution certificate → name and download it.

Its name doesn't have to match anything: the workflow reads the name out of the
profile it installs and writes it into the export options, so the secret can be
rotated or renamed without touching the repo. It does have to *not* look like one
of Xcode's — the guard rejects the `Mac Team … Provisioning Profile: <bundle id>`
shape, and a profile carrying `ProvisionedDevices`, which would be a development
profile under a distribution name. The one in use is **`BrowBro Mac App Store CI`**,
created 2026-09-13.

An earlier attempt stored the Xcode-generated profile here and got as far as the
export before failing, because that profile carries no `IsXcodeManaged` key for the
guard to find — hence the check on the name.

Then, from a checkout — the values never pass through a browser field:

```sh
base64 -i ~/Desktop/BrowBro-mas.p12 | gh secret set MAS_CERT_P12_BASE64
gh secret set MAS_CERT_P12_PASSWORD           # the p12 export password
gh secret set APPSTORE_CONNECT_KEY_ID         # e.g. ABCD123456
gh secret set APPSTORE_CONNECT_ISSUER_ID      # the UUID on the same page
gh secret set APPSTORE_CONNECT_PRIVATE_KEY < ~/Downloads/AuthKey_ABCD123456.p8

base64 -i ~/Downloads/BrowBro_Mac_App_Store.provisionprofile \
  | gh secret set MAS_PROVISIONING_PROFILE_BASE64
```

### Why the profile is a secret and not cloud signing

`-allowProvisioningUpdates` would fetch the profile on its own and none of this
would be needed — but distribution cloud signing requires an API key with the
**Admin** role. A non-Admin key fails at export with `Cloud signing permission
error` followed by `No profiles for 'cloud.tiagomoraes.browbro' were found`, which
reads like a missing profile rather than a missing permission.

Rather than hand a CI credential the run of the account, the key stays App
Manager — enough to upload a build, nothing else — and the profile travels with
it. The trade is that the profile **expires 2027-08-30** and has to be re-created
then. The workflow prints its name and expiry on every run, and fails early if it
stops matching the bundle id or the name in `ExportOptions.plist`, so this surfaces
as a dated line in the log rather than a signing error a year from now.

The workflow fails with the missing secret's name rather than a signing error
several minutes in.

### Running it

`workflow_dispatch` only appears once the workflow file is on the **default
branch** (`develop`) — so this has to be merged before the first manual run, even
though the run itself can build any ref.

```sh
gh workflow run app-store.yml -f dry_run=true          # archive, verify, keep the .pkg
gh workflow run app-store.yml -f ref=develop           # upload + product page, no review
gh workflow run app-store.yml -f submit=true           # ...and send it to App Review
gh workflow run app-store.yml -f screenshots=true      # ...also replace the screenshots
gh workflow run app-store.yml -f build_number=12       # pin the build number by hand
```

A published GitHub Release triggers it with no inputs, building that release's tag,
and **submits for review** unless the release is marked as a prerelease.

`dry_run` stops before anything leaves the runner: it archives, runs
`verify-mas-app.sh`, exports the `.pkg` and attaches it to the run. It is the way
to test a signing or project change without burning a build number.

`MAX_XCODE_MAJOR` in the workflow pins the toolchain to a major Connect accepts.
Raise it once Apple starts accepting the next one; the pin is there so a runner
image bump can't silently start producing builds that fail validation.

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
