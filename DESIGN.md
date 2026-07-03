# BrowBro — Design & v1 Plan

BrowBro is a lightweight macOS menu-bar app that becomes your default browser and,
whenever you click a web link, pops an instant picker so you choose which browser —
or which **Chrome profile** — opens it. Open-source, in the spirit of Velja.

> Name: **BrowBro** (display) / `browbro` (repo, bundle id `so.aca.browbro`, CLI).

## How it works (three parts)

1. **Intercept** — registered as the system default browser; receives clicked links as
   `kAEGetURL` Apple Events (and the modern `application(_:open:)` path).
2. **Pick** — an instant, keyboard-driven picker appears at the cursor.
3. **Launch** — opens the chosen browser, launching Chrome with
   `--profile-directory="…"` for profile targets.

## v1 scope — the picker, done excellently

- **Placement:** at the cursor, screen-edge clamped.
- **Keyboard-first:** `1`–`9` / first-letter jump to a target; `↑↓` to move; `Enter` =
  highlighted; `Esc` / click-away cancels (link doesn't open); type-to-filter when the
  list grows.
- **Entries:** browser icon + name; **Chrome profiles show avatar/color + profile name**,
  grouped under Chrome. Slim header shows the URL + best-effort source app.
- **Pre-selection:** configurable default highlighted (one-key `Enter`); optional
  remember-last-used. If only one target exists, skip the picker.
- **Targets:** auto-detect every installed `http(s)` handler + Chrome profiles (parsed from
  `~/Library/Application Support/Google/Chrome/Local State`). Edge/Brave/Vivaldi
  (same `--profile-directory` mechanism) structured to drop in later.
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
| Distribution | Local unsigned/ad-hoc build now → notarized DMG + Homebrew cask later |

## Out of scope → milestone 2+

Rules engine · "always use X for this site" · URL transforms (unshorten / strip tracking) ·
routing to native apps (Zoom/Slack deep links) · hold-modifier-to-bypass ·
other Chromium browsers' profiles · Arc / Firefox.

## Recommended build order (de-risk first)

1. 🔥 **Riskiest slice** — register as default browser + catch a clicked link + show the URL.
   *(current: branch `feat/default-browser-handler`)*
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
