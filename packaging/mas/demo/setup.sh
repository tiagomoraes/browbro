#!/usr/bin/env bash
#
# Stage this Mac for the App Review screen recording (Guideline 2.1).
#
# A maintainer's Mac is a bad film set, and this undoes the three ways it shows:
#
#   - every other BrowBro copy on disk (the DMG build, dev builds, archives) is an
#     http handler too, so the picker would list a target called "BrowBro" — next to
#     whatever else claims http (ChatGPT, Playwright's Chrome for Testing…). Every
#     handler that is not a known browser is unregistered from LaunchServices for
#     the take.
#   - the sandbox container remembers onboarding, and the launch helper in
#     ~/Library/Application Scripts would skip its install prompt. Both are stashed,
#     so the take shows the true first run.
#   - the daily build is the default browser, so onboarding would read
#     "Currently: BrowBro". Chrome takes the default for the take.
#
# Everything is recorded under $STATE; teardown.sh puts it back.
#
# Usage:
#   packaging/mas/build-mas.sh && packaging/mas/demo/setup.sh [path/to/BrowBro.app]
#
set -euo pipefail
cd "$(dirname "$0")/../../.."
DEMO="packaging/mas/demo"

SRC="${1:-build/mas/Build/Products/Debug/BrowBro.app}"
STATE="$HOME/Library/Caches/browbro-demo"
APP="$HOME/Applications/BrowBro.app"
CONTAINER="$HOME/Library/Containers/cloud.tiagomoraes.browbro"
HELPER="$HOME/Library/Application Scripts/cloud.tiagomoraes.browbro/browbro-launch"
CHROME="/Applications/Google Chrome.app"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[ -d "$STATE" ] && { echo "✗ Already staged ($STATE). Run $DEMO/teardown.sh first." >&2; exit 1; }
[ -d "$SRC" ] || { echo "✗ No build at $SRC — run packaging/mas/build-mas.sh" >&2; exit 1; }
[ -e "$APP" ] && { echo "✗ $APP already exists; not overwriting it." >&2; exit 1; }
[ -d "$CHROME" ] || { echo "✗ $CHROME is missing — the take needs it." >&2; exit 1; }
mkdir -p "$STATE"

echo "▶ Quitting BrowBro…"
pgrep -f "/Applications/BrowBro.app/Contents/MacOS/BrowBro" >/dev/null && touch "$STATE/was-running"
for id in so.aca.browbro cloud.tiagomoraes.browbro; do
  osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1 || true
done
sleep 1

swift "$DEMO/default-browser.swift" get > "$STATE/default-browser"
echo "▶ Default browser was: $(cat "$STATE/default-browser")"
case "$(cat "$STATE/default-browser")" in
  *BrowBro*)
    echo "  → handing it to Chrome for the take. Click “Use “Chrome”” in the panel."
    swift "$DEMO/default-browser.swift" set "$CHROME" >/dev/null \
      || { echo "✗ Chrome is not the default — the panel was refused or dismissed. Run teardown.sh, then setup.sh again." >&2; exit 1; }
    ;;
esac

# teardown.sh deletes a container only when this step recorded one way or the other —
# a setup that stopped earlier must not cost the real one.
if [ -d "$CONTAINER" ]; then
  echo "▶ Stashing the sandbox container…"
  mv "$CONTAINER" "$STATE/container"
else
  touch "$STATE/no-container"
fi

if [ -f "$HELPER" ]; then
  echo "▶ Stashing the launch helper…"
  mv "$HELPER" "$STATE/browbro-launch"
fi

echo "▶ Staging ${APP}…"
ditto "$SRC" "$APP"
"$LSREG" -f "$APP"

# Hide every http handler that isn't a browser. LaunchServices re-registers some
# paths behind our back (an app in /Applications, one that just quit), so repeat
# until the list holds still.
KEEP="com.google.Chrome com.apple.Safari org.mozilla.firefox app.zen-browser.zen \
  com.microsoft.edgemac com.brave.Browser company.thebrowser.Browser com.vivaldi.Vivaldi \
  com.operasoftware.Opera com.kagi.kagimacOS"
echo "▶ Hiding http handlers that aren't browsers…"
: > "$STATE/registered"
for _ in 1 2 3 4 5; do
  hidden=0
  while IFS= read -r path; do
    [ "$path" = "$APP" ] && continue
    id="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$path/Contents/Info.plist" 2>/dev/null || true)"
    case " $KEEP " in *" $id "*) continue ;; esac
    grep -qxF "$path" "$STATE/registered" || echo "$path" >> "$STATE/registered"
    "$LSREG" -u "$path" 2>/dev/null || true
    hidden=1
  done < <(swift -e 'import AppKit
for u in NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!) { print(u.path) }')
  [ "$hidden" = 0 ] && break
  sleep 1
done
echo "  $(wc -l < "$STATE/registered" | tr -d ' ') apps, listed in $STATE/registered"

# Links to click on camera. TextEdit opens .rtf links with a plain click.
cat > "$STATE/Links.html" <<'HTML'
<html><body style="font: 18px -apple-system">
<h2>Links to open</h2>
<p><a href="https://www.apple.com/macos/">https://www.apple.com/macos/</a></p>
<p><a href="https://developer.apple.com/app-store/review/guidelines/">https://developer.apple.com/app-store/review/guidelines/</a></p>
<p><a href="https://github.com/tiagomoraes/browbro">https://github.com/tiagomoraes/browbro</a></p>
<p><a href="https://example.com/">https://example.com/</a></p>
</body></html>
HTML
textutil -convert rtf "$STATE/Links.html" -output "$STATE/Links.rtf"

echo
echo "▶ http handlers the picker can see now:"
swift -e 'import AppKit
for u in NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!) { print("  " + u.path) }'

cat <<EOF

✅ Staged. Record with ⌘⇧5 → Record Entire Screen, then follow the shot list in
   $DEMO/README.md. Links document: $STATE/Links.rtf
   When done: $DEMO/build-video.sh, then $DEMO/teardown.sh
EOF
