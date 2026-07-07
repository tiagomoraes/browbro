# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Private windows.** A new **Settings → Private windows** switch adds picker entries that
  open links in a browser's incognito/private window — per browser and even per Chrome
  profile ("Work Incognito" opens that profile's incognito window). Supported for Chrome,
  Chromium, Brave, Edge, Vivaldi, Opera, and Firefox; entries wear a sunglasses badge so a
  private pick is unmistakable. Safari is not supported (it offers no way to open a private
  window programmatically).

## [0.1.5] - 2026-07-06

### Added

- **Hold a key to pick.** A new **Settings → Behavior** option, "Ask only when I hold a key",
  makes a plain click open your default browser straight away and only pops the picker when you
  hold a modifier while clicking. Choose the trigger key (⌘ / ⌥ / ⌃ / ⇧, default ⌥) and which
  browser plain clicks open in. The picker's always-on behavior is unchanged when the option
  is off.

## [0.1.4] - 2026-07-05

### Added

- **In-app updates.** BrowBro now updates itself (via [Sparkle](https://sparkle-project.org)),
  so DMG and Homebrew installs no longer need a manual re-download. **Settings → Updates** has a
  **Check Now** button and an **Automatically check for updates** toggle, and the menu-bar
  dropdown gains a **Check for Updates…** item. Updates are verified with an EdDSA signature and
  installed in place — and, unlike a manual download, they skip the first-run "Open Anyway"
  prompt. See [docs/UPDATES.md](docs/UPDATES.md).
- A **version indicator** in Settings: the current version and build show at the bottom of the
  window ("BrowBro 0.1.4 (4)").

## [0.1.3] - 2026-07-05

### Added

- Support the project from inside the app: a **Support the project** group in Settings
  (Sponsor on GitHub, Buy me a coffee, Star the repo) and a **Support BrowBro** item in the
  menu-bar dropdown. Any amount helps — no tiers, no minimums.

### Fixed

- A background Settings window no longer jumps to the front every time a link is routed.
  Opening a link activates BrowBro (it's the default handler) and the window server would
  raise its front window; the routed-link path now restores the window to its prior stacking
  order. The picker is also non-activating now, so the app you clicked the link in keeps focus.
- Restored the **Settings…** (⌘,) menu command.

## [0.1.2] - 2026-07-04

### Changed

- The DMG's mounted volume now shows the BrowBro icon (instead of the generic disk icon).

### Added

- Notarization pipeline: `packaging/notarize/notarize-release.sh` and `docs/NOTARIZING.md`
  for producing a signed + notarized DMG once a Developer ID certificate is available. Opt-in;
  the default build is unchanged. The app itself is unchanged from 0.1.0.

## [0.1.1] - 2026-07-04

### Changed

- Styled the DMG installer window: a branded background with the BrowBro wordmark and a
  drag-BrowBro-onto-Applications arrow, replacing the bare Finder window. Retina background,
  reproducible via `packaging/dmg/`. The app itself is unchanged from 0.1.0.

## [0.1.0] - 2026-07-04

First public preview. Universal (Apple Silicon + Intel) build, code-signed but not
yet notarized, so the first launch needs a manual "Open Anyway" (see the release notes).

### Added

- The cursor picker: a keyboard-first popover at the click point. `1`–`9` opens a target
  directly, `↑`/`↓` and first-letter jumps move the highlight, `Enter` opens, `Esc` cancels.
  Browsers and Chrome profiles appear as peers in one flat list, with profile color swatches
  and quick-key badges.
- Menu-bar dropdown: default-browser status at a glance, one-click "Set as default browser"
  when needed, recent links that re-open the picker, and Settings/Quit actions.
- Settings window: default-browser status with one-click restore of the previous default,
  Chrome-profile access management, a "Shown in the picker" catalog with drag-to-reorder and
  show/hide per target, and behavior toggles (remember last used, skip picker for a single
  target, launch at login).
- First-run onboarding with a transparent, reversible default-browser takeover.
- BrowBro brand: the unibrow logomark, a monochrome menu-bar template glyph, the blue-squircle
  app icon, and a full set of native design tokens (adaptive light/dark) from the BrowBro
  Design System.
- Marketing website (static, in `site/`) published to GitHub Pages at browbro.tiagomoraes.cloud.
- Project scaffolding: Gitflow branching model, contribution guidelines, issue/PR templates.

[Unreleased]: https://github.com/tiagomoraes/browbro/compare/v0.1.5...HEAD
[0.1.5]: https://github.com/tiagomoraes/browbro/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/tiagomoraes/browbro/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/tiagomoraes/browbro/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/tiagomoraes/browbro/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/tiagomoraes/browbro/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/tiagomoraes/browbro/releases/tag/v0.1.0
