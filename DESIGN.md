# BrowBro — Design & v1 Plan

BrowBro is a lightweight macOS menu-bar app that becomes your default browser and,
whenever you click a web link, pops an instant picker so you choose which browser —
or which **Chrome profile** — opens it. Open-source, in the spirit of Velja.

> Name: **BrowBro** (display) / `browbro` (repo, bundle id `cloud.tiagomoraes.browbro`, CLI).

## How it works (three parts)

1. **Intercept** — registered as the system default browser; receives clicked links as
   `kAEGetURL` Apple Events (and the modern `application(_:open:)` path).
2. **Pick** — an instant, keyboard-driven picker appears at the cursor.
3. **Launch** — opens the chosen browser, launching Chrome with
   `--profile-directory="…"` for profile targets and the browser's own private-window flag
   for Private Window targets.

## v1 scope — the picker, done excellently

- **Placement:** at the cursor, screen-edge clamped.
- **Keyboard-first:** `1`–`9` opens that target immediately (the badge is its position);
  a letter moves the highlight to the first target starting with it; `↑↓` to move;
  `Enter` = highlighted; `Esc` / click-away cancels (link doesn't open).
- **Entries:** browser icon + name; **Chrome profiles show a color swatch + profile name**
  (and email). Browsers and profiles are peers in one flat list — profiles aren't grouped
  under Chrome. Slim header shows the URL + best-effort source app.
- **Pre-selection:** the top of the list is highlighted, so one-key `Enter` opens it;
  **Remember last used** highlights your previous pick instead. **Skip picker for a single
  target** opens the only shown target directly.
- **Targets:** auto-detect every installed `http(s)` handler + Chrome profiles (parsed from
  `~/Library/Application Support/Google/Chrome/Local State`). **Settings → Shown in the
  picker** reorders (drag) and hides them. Edge/Brave/Vivaldi profiles (same
  `--profile-directory` mechanism) are structured to drop in later.
- **Private windows** (opt-in, **Settings → Private windows**): extra entries that open a
  browser's — or a Chrome profile's — incognito/private window. Chromium family, Edge,
  Opera and Firefox; not Safari, which has no programmatic way in. See
  [ADR-0001](docs/adr/0001-private-windows-as-derived-opt-in-targets.md).
- **Hold a key to pick** (opt-in, **Settings → Behavior → Ask only when I hold a key**): a
  plain click opens a chosen browser straight away; hold ⌘, ⌥ or ⇧ while clicking to get
  the picker.
- **Onboarding & trust:** guided first run captures the *current* default browser, stores
  it, shows it as a target, and offers one-click "restore as default". Transparent,
  reversible takeover.

## Architecture

| Area | Decision |
|------|----------|
| Stack | Native **Swift + SwiftUI** |
| App type | Menu-bar-only accessory (`LSUIElement`), resident, login item (`SMAppService`) so the picker is instant |
| Project | Xcode project generated from `project.yml` via **xcodegen** |
| URL reception | `CFBundleURLTypes` http/https + `kAEGetURL` Apple Event |
| Persistence | `UserDefaults` (v1 prefs); JSON/SwiftData for rules in milestone 2 |
| Min OS | macOS 14 (Sonoma)+ |
| Distribution | Dual channel: notarized DMG + Homebrew + Sparkle, and a sandboxed Mac App Store target (`BrowBroMAS`). See [docs/NOTARIZING.md](docs/NOTARIZING.md) and [docs/MAS.md](docs/MAS.md). |

## Out of scope → milestone 2+

Rules engine · "always use X for this site" · URL transforms (unshorten / strip tracking) ·
routing to native apps (Zoom/Slack deep links) · type-to-filter for long lists ·
profiles in other browsers (Edge / Brave / Vivaldi, Arc, Firefox).

_(Hold-a-key-to-pick (0.1.5) and private windows (0.1.6) came after v1; both are described
above.)_

## Build order (de-risk first)

v1 was built in this order, and all of it shipped in 0.1.0:

1. 🔥 **Riskiest slice** — register as default browser + catch a clicked link + show the URL.
2. Launcher — open a chosen browser; then Chrome-with-profile.
3. Target discovery — enumerate browsers + parse Chrome profiles.
4. The picker UI.
5. Onboarding + Settings + login item.
6. Polish — icons, animation, edge cases.

## Building locally

```sh
brew install xcodegen   # one-time
./build.sh              # generate project, build, register, launch
```

Prove link reception without changing your default browser:

```sh
open -a BrowBro "https://example.com/it-works"
```
