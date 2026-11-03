#!/usr/bin/env bash
#
# Undo setup.sh: drop the demo build and its container, re-register the BrowBro
# copies it hid, put the stashed container back, restore the default browser and
# relaunch the daily build if it was running.
#
# Restoring the default browser raises the system panel; it cannot be done without
# that click on macOS 27, so this says so instead of pretending it happened.
#
set -euo pipefail
cd "$(dirname "$0")/../../.."
DEMO="packaging/mas/demo"

STATE="$HOME/Library/Caches/browbro-demo"
APP="$HOME/Applications/BrowBro.app"
CONTAINER="$HOME/Library/Containers/cloud.tiagomoraes.browbro"
HELPER="$HOME/Library/Application Scripts/cloud.tiagomoraes.browbro/browbro-launch"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[ -d "$STATE" ] || { echo "✗ Nothing staged ($STATE is missing)." >&2; exit 1; }

echo "▶ Quitting the demo build…"
osascript -e 'tell application id "cloud.tiagomoraes.browbro" to quit' >/dev/null 2>&1 || true
sleep 1

if [ -d "$APP" ]; then
  "$LSREG" -u "$APP" 2>/dev/null || true
  rm -rf "$APP"
fi

if [ -d "$STATE/container" ]; then
  echo "▶ Restoring the sandbox container…"
  rm -rf "$CONTAINER"
  mv "$STATE/container" "$CONTAINER"
elif [ -e "$STATE/no-container" ]; then
  rm -rf "$CONTAINER"   # created by the take; there was none before
fi

# The take installs a fresh helper; put the stashed one back over it.
if [ -f "$STATE/browbro-launch" ]; then
  mv -f "$STATE/browbro-launch" "$HELPER"
fi

# setup.sh can stop part-way (a refused default-browser panel); undo only what it did.
if [ -f "$STATE/registered" ]; then
  echo "▶ Re-registering the BrowBro copies…"
  while IFS= read -r path; do
    [ -d "$path" ] && "$LSREG" -f "$path"
  done < "$STATE/registered"
fi

prior="$(cat "$STATE/default-browser" 2>/dev/null || true)"
if [ -n "$prior" ] && [ "$(swift "$DEMO/default-browser.swift" get)" != "$prior" ]; then
  echo "▶ Restoring the default browser to $prior — click “Use” in the system panel."
  swift "$DEMO/default-browser.swift" set "$prior" >/dev/null \
    || echo "  ⚠︎ Still not $prior. Set it from BrowBro → Settings → Default browser." >&2
fi

if [ -e "$STATE/was-running" ]; then
  open -g "/Applications/BrowBro.app"
fi

rm -rf "$STATE"
echo "✅ Back to normal."
