# browbro
BowBro is a macos application that let's the user select the browser they want to use to open a link from the web.

## Install

Requires macOS 14 (Sonoma) or later.

**Homebrew:**

```sh
brew install --cask tiagomoraes/browbro/browbro
```

**Or download the DMG** from the [latest release](https://github.com/tiagomoraes/browbro/releases/latest)
and drag BrowBro into Applications.

BrowBro is not yet notarized, so macOS blocks it on first launch. To open it: go to
**System Settings > Privacy & Security** and click **Open Anyway** (or run
`xattr -dr com.apple.quarantine "/Applications/BrowBro.app"`).

## Website

The marketing site lives in [`site/`](site/): a self-contained static site (no build
step) that mirrors the app's design system. It's published to GitHub Pages at
**[browbro.tiagomoraes.cloud](https://browbro.tiagomoraes.cloud)** by the
[`deploy-pages`](.github/workflows/deploy-pages.yml) workflow on every push to `develop`
that touches `site/`. To preview locally: `cd site && python3 -m http.server` then open
the printed URL.

## Contributing

Contributions are welcome! Active development happens on the `develop` branch. `main` is
reserved for tagged releases. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the branching
model, naming conventions, and release process, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
before opening an issue or pull request.
