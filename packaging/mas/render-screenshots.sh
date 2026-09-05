#!/usr/bin/env bash
#
# Render the English App Store marketing screenshots from mock.html.
# The app preview video is a separate shape — see render-preview.sh.
#
# mock.html is authored at 1280x800 CSS px; Chrome renders it at
# devicePixelRatio 2, which lands exactly on the 2560x1600 (16:10) size
# App Store Connect accepts. Text and hairlines are drawn at 2x rather than
# upscaled, so nothing is soft.
#
# Output: 2560x1600 PNG, no alpha, fictional UI only.
#
set -euo pipefail
cd "$(dirname "$0")/../.."

OUT="packaging/mas/screenshots"
MOCK="$PWD/packaging/mas/screenshots/mock.html"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[ -x "$CHROME" ] || { echo "error: Chrome not found at $CHROME" >&2; exit 1; }

# shot slug -> output file, in the order they are uploaded to Connect.
SHOTS=(
  "hero:01-hero.png"
  "profiles:02-profiles.png"
  "keys:03-keys.png"
  "private:04-private.png"
  "modifier:05-modifier.png"
  "trust:06-trust.png"
  "catalog:07-catalog.png"
  "privacy:08-privacy.png"
)

render() {
  local shot="$1" dest="$2"
  local tmp jpg
  tmp=$(mktemp -t browbro-shot).png
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=1280,800 \
    --default-background-color=00000000 \
    --screenshot="$tmp" "file://${MOCK}?shot=${shot}" >/dev/null 2>&1
  # Guard the exact pixel size Connect wants, then flatten alpha via JPEG.
  sips -z 1600 2560 "$tmp" --out "$dest" >/dev/null
  jpg=$(mktemp -t browbro-shot).jpg
  sips -s format jpeg -s formatOptions 100 "$dest" --out "$jpg" >/dev/null
  sips -s format png "$jpg" --out "$dest" >/dev/null
  rm -f "$tmp" "$jpg"
  printf '  %-28s %s\n' "$dest" "$(sips -g pixelWidth -g pixelHeight "$dest" | awk '/pixel/{printf "%s ", $2}')"
}

echo "▶ Screenshots (2560×1600, no alpha)"
mkdir -p "$OUT"
for entry in "${SHOTS[@]}"; do
  render "${entry%%:*}" "$OUT/${entry##*:}"
done

# Drop leftovers from earlier naming schemes so the folder is exactly the set
# that gets uploaded.
rm -f "$OUT"/01-scene.png "$OUT"/01-picker.png "$OUT"/02-profiles-old.png \
      "$OUT"/03-keys-old.png "$OUT"/04-onboarding.png "$OUT"/04-trust.png \
      "$OUT"/05-settings.png "$OUT"/05-catalog.png

echo "▶ App preview is a different shape (16:9) — packaging/mas/render-preview.sh"

echo "✅ done"
