# Product

## Register

brand

## Users

macOS users — developers, designers, consultants — who juggle several browsers or Chrome
profiles and click links all day from Slack, Mail, Messages, and terminals. They arrive at
the site from a friend's recommendation or a GitHub link, decide within a minute whether to
download, and care that the app is native, fast, and trustworthy (it takes over the default
browser, so trust is the whole game).

## Product Purpose

BrowBro is a free, open-source macOS menu-bar app that intercepts clicked links and pops a
keyboard-first picker at the cursor, so every link opens in the right browser or Chrome
profile. The site's job: demonstrate that interaction (the live demo IS the pitch), earn
trust (open source, reversible takeover, local-only routing), and convert to a download or
`brew install`.

## Brand Personality

Native, playful, trustworthy. Sounds like a helpful friend ("Every link, your call",
"Buy the bro a coffee"); looks like macOS itself — the site is built from faux Mac windows,
menu bars, and the app's own popover, pixel-faithful to the app's design tokens.

## Anti-references

- Generic SaaS landing pages: gradient meshes, hero-metric templates, pricing-tier cards.
- Electron-app marketing that feels web-first rather than Mac-native.
- Donation pages that guilt or gate: no tiers, no locked features, no "minimum" framing.

## Design Principles

1. **The UI is the illustration.** Features are shown as working facsimiles of the real app
   (picker, settings window, terminal), never abstract art or static screenshots.
2. **Pixel-faithful to the app.** The site consumes the app's design tokens verbatim; if it
   wouldn't fit macOS, it doesn't ship on the site.
3. **Keyboard-first everywhere.** Interactive demos honor the app's keys (1–9, arrows,
   Enter, Esc).
4. **Trust through transparency.** Open source, reversible default-browser takeover, and
   local-only routing are stated plainly, never buried.
5. **Asking, never pressuring.** Support is invited with warmth; free actions (starring,
   sharing) are presented as equals to money.

## Accessibility & Inclusion

- Light and dark themes, honoring the system preference with a manual override.
- `prefers-reduced-motion` respected across demos and scroll reveals.
- Full keyboard operability with visible focus (`--focus-ring`).
- Body text at ≥ 4.5:1 contrast in both themes.
