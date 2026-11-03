# DMG installer packaging

Assets and script for BrowBro's styled drag-to-Applications installer window.

- `background.html` : source of the installer background art (rendered to PNG).
- `background.tiff` : the baked HiDPI background (1x + 2x), used by the DMG.
- `dmgbuild-settings.py` : window size, icon positions, and background for [dmgbuild](https://dmgbuild.readthedocs.io).
- `build-dmg.sh` : builds a universal **local preview** DMG, `build/BrowBro-preview.dmg`,
  signed with your Apple Development certificate and not notarized. Never ship it:
  release DMGs come only from `packaging/notarize/notarize-release.sh`
  ([docs/NOTARIZING.md](../../docs/NOTARIZING.md)).

## Regenerate the background

Open `background.html` at 660x460 (device pixel ratio 2), screenshot to
`bg@2x.png` (1320x920), then:

```sh
sips --resampleHeightWidth 460 660 bg@2x.png --out bg-1x.png
tiffutil -cathidpicheck bg-1x.png bg@2x.png -out background.tiff
```

## Build a preview DMG

A quick look at the installer window on your own Mac. Gatekeeper blocks this DMG
anywhere else, so it is never a release; for that, see
[docs/NOTARIZING.md](../../docs/NOTARIZING.md).

```sh
pipx install dmgbuild                 # a bare pip install fails on Homebrew Python (PEP 668)
packaging/dmg/build-dmg.sh            # writes build/BrowBro-preview.dmg (local preview only)
```
