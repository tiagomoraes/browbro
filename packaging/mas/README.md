# Mac App Store packaging

Sandboxed, Sparkle-free variant of BrowBro for App Store Connect.

- `BrowBro.entitlements` : App Sandbox + user-selected folder + app-scoped bookmarks.
- `ExportOptions.plist` : `xcodebuild -exportArchive` into a `.pkg`.
- `build-mas.sh` : local Debug/Release build that refuses to succeed if Sparkle leaked in.
- `screenshots/mock.html` + `render-screenshots.sh` : the eight English marketing
  frames (2560×1600, 16:10), authored at 1280×800 and rendered at dpr 2.
- `screenshots/mock.html?audit=1` : unclips every frame and draws the 1280×800
  boundary in red, so overflow shows up instead of being silently cut.
- `previews/preview.html` + `render-preview.sh` : the app preview film
  (1920×1080, 16:9, 17.6s) — previews are a different shape than screenshots.

The walkthrough — Connect listing, screenshots, review notes, dual-channel caveats —
is [docs/MAS.md](../../docs/MAS.md).
