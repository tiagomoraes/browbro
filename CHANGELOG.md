# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The cursor picker: a keyboard-first popover at the click point — `1`–`9` opens a target
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
- Project scaffolding: Gitflow branching model, contribution guidelines, issue/PR templates.
