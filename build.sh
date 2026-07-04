#!/usr/bin/env bash
#
# Local dev build for BrowBro (Decision 7: unsigned/ad-hoc, no notarization).
# Generates the Xcode project from project.yml, builds, registers the app with
# LaunchServices, and launches it.
#
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Build/Products/Debug/BrowBro.app"
INSTALLED="/Applications/BrowBro.app"

echo "▶ Generating Xcode project (xcodegen)…"
xcodegen generate

echo "▶ Building…"
# Signing identity/team come from project.yml (Apple Development, required for TCC).
xcodebuild \
  -project BrowBro.xcodeproj \
  -scheme BrowBro \
  -configuration Debug \
  -derivedDataPath build \
  -quiet

echo "▶ Installing to /Applications (stable location for TCC & LaunchServices)…"
pkill -x BrowBro 2>/dev/null || true
ditto "$APP" "$INSTALLED"

echo "▶ Registering with LaunchServices…"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$APP" 2>/dev/null || true   # unregister the build-folder copy
"$LSREGISTER" -f "$INSTALLED"

echo "▶ Launching BrowBro…"
open "$INSTALLED"

cat <<'EOF'

✅ BrowBro is running (look for the unibrow mark in the menu bar).

Prove link reception WITHOUT changing your default browser:
    open -a BrowBro "https://example.com/it-works"

Then open the menu-bar item — the URL should appear under "Last received link".
EOF
