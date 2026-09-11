#!/usr/bin/env bash
#
# Build the Mac App Store variant (sandboxed, no Sparkle) for local testing.
#
# Does NOT install to /Applications. The MAS target shares bundle id
# `cloud.tiagomoraes.browbro` with the daily DMG build, so copying it over would replace
# the Sparkle-signed app and reset TCC. Run the product from the build folder.
#
# Usage:
#   packaging/mas/build-mas.sh            # Debug
#   packaging/mas/build-mas.sh Release
#
set -euo pipefail
cd "$(dirname "$0")/../.."

CONFIG="${1:-Debug}"
DD="${DD:-build/mas}"
APP="$DD/Build/Products/$CONFIG/BrowBro.app"

echo "▶ Generating Xcode project…"
xcodegen generate >/dev/null

echo "▶ Building BrowBroMAS ($CONFIG)…"
xcodebuild -project BrowBro.xcodeproj -scheme BrowBroMAS -configuration "$CONFIG" \
  -derivedDataPath "$DD" -quiet

if [ ! -d "$APP" ]; then
  echo "✗ Expected app missing: $APP" >&2
  exit 1
fi

packaging/mas/verify-mas-app.sh "$APP"

echo "✅ $APP"
echo "   Sandboxed, no Sparkle. Drive a link without touching /Applications:"
echo "     open -a \"$APP\" \"https://example.com/mas-test\""
