#!/usr/bin/env bash
#
# Compress the take into something App Review's reply form accepts: H.264,
# 1920 wide, 30 fps, no audio. A raw Retina capture is several hundred MB.
# Several inputs (segments of a scripted take) are joined in the order given.
#
# Usage:
#   packaging/mas/demo/build-video.sh                    # newest Screen Recording on the Desktop
#   packaging/mas/demo/build-video.sh take.mov
#   packaging/mas/demo/build-video.sh 01.mkv 02.mkv …    # concatenated
#
set -euo pipefail
cd "$(dirname "$0")/../../.."

OUT="build/review/browbro-app-review.mp4"
if [ $# -eq 0 ]; then
  set -- "$(ls -t "$HOME"/Desktop/Screen\ Recording*.mov 2>/dev/null | head -1)"
fi
for f in "$@"; do
  [ -f "$f" ] || { echo "✗ No recording at '$f' (pass the .mov path)." >&2; exit 1; }
done
mkdir -p "$(dirname "$OUT")"

LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT
for f in "$@"; do
  printf "file '%s'\n" "$(cd "$(dirname "$f")" && pwd)/$(basename "$f")" >> "$LIST"
done

ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LIST" \
  -vf "scale=1920:-2:flags=lanczos,fps=30" \
  -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p -movflags +faststart -an \
  "$OUT"

echo "✅ $OUT — $(du -h "$OUT" | cut -f1), $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | cut -d. -f1)s"
