# DMG installer packaging

Assets and script for BrowBro's styled drag-to-Applications installer window.

- `background.html` : source of the installer background art (rendered to PNG).
- `background.tiff` : the baked HiDPI background (1x + 2x), used by the DMG.
- `dmgbuild-settings.py` : window size, icon positions, and background for [dmgbuild](https://dmgbuild.readthedocs.io).
- `build-dmg.sh` : builds a signed, universal `BrowBro.dmg`.

## Regenerate the background

Open `background.html` at 660x460 (device pixel ratio 2), screenshot to
`bg@2x.png` (1320x920), then:

```sh
sips --resampleHeightWidth 460 660 bg@2x.png --out bg-1x.png
tiffutil -cathidpicheck bg-1x.png bg@2x.png -out background.tiff
```

## Build the DMG

```sh
pip install dmgbuild
packaging/dmg/build-dmg.sh            # writes build/BrowBro.dmg
```
