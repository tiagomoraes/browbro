#!/usr/bin/env bash
#
# Render the App Store app preview (macOS): 1920x1080, 16:9, H.264.
#
# App Store Connect wants a different shape for previews than for screenshots —
# previews are 16:9 at 1920x1080, screenshots are 16:10. Source is
# previews/preview.html, authored at 960x540 CSS px and rendered at dpr 2.
#
# Duration lands at 17.6s (Connect accepts 15-30s), 30fps, ~10 Mbps, with a
# silent stereo AAC track so every track in the file is enabled.
#
set -euo pipefail
cd "$(dirname "$0")/../.."

PREV="packaging/mas/previews"
SRC="$PWD/$PREV/preview.html"
FRAMES="$PREV/.frames"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[ -x "$CHROME" ] || { echo "error: Chrome not found at $CHROME" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "error: ffmpeg not installed (brew install ffmpeg)" >&2; exit 1; }

# act slug : seconds on screen
ACTS=(open:2.6 desk:2.4 pick:3.2 key:2.8 opened:3.0 profiles:3.2 end:2.8)
XFADE=0.4

mkdir -p "$FRAMES"
echo "▶ Acts (1920×1080)"
i=0
for entry in "${ACTS[@]}"; do
  act="${entry%%:*}"
  out=$(printf '%s/%02d-%s.png' "$FRAMES" "$i" "$act")
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=960,540 \
    --screenshot="$out" "file://${SRC}?act=${act}" >/dev/null 2>&1
  echo "  $out"
  i=$((i + 1))
done

# Build the -loop inputs and the xfade chain. Offset n is where transition n
# starts on the stream built so far: sum(d[0..n]) - (n+1)*XFADE.
inputs=(); filter=""; acc=0
i=0
for entry in "${ACTS[@]}"; do
  act="${entry%%:*}"; dur="${entry##*:}"
  inputs+=(-loop 1 -t "$dur" -i "$(printf '%s/%02d-%s.png' "$FRAMES" "$i" "$act")")
  acc=$(echo "$acc + $dur" | bc)
  if [ "$i" -gt 0 ]; then
    off=$(echo "$acc - $dur - $i * $XFADE" | bc)
    prev=$([ "$i" -eq 1 ] && echo "[0][1]" || echo "[x$((i - 1))][$i]")
    filter+="${prev}xfade=transition=fade:duration=${XFADE}:offset=${off}[x${i}];"
  fi
  i=$((i + 1))
done
last="x$((i - 1))"
filter+="[$last]fps=30,format=yuv420p[v]"

echo "▶ Encoding (H.264, 30fps, silent stereo track)"
ffmpeg -y -hide_banner -loglevel error \
  "${inputs[@]}" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -filter_complex "$filter" \
  -map "[v]" -map "${i}:a" \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
  -b:v 10M -maxrate 12M -bufsize 24M -r 30 \
  -c:a aac -b:a 256k -ar 44100 -ac 2 -shortest \
  -movflags +faststart \
  "$PREV/01-every-link.mp4"

rm -f "$PREV/01-moment.mp4"
ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$PREV/01-every-link.mp4"
echo "✅ $PREV/01-every-link.mp4"
