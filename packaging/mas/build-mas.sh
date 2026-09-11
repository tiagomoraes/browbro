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

echo "▶ Checking the App Store binary…"
if [ -d "$APP/Contents/Frameworks/Sparkle.framework" ]; then
  echo "✗ Sparkle.framework is in the MAS build — it must not ship (2.4.5(vii))." >&2
  exit 1
fi
if grep -q SUFeedURL "$APP/Contents/Info.plist" 2>/dev/null; then
  echo "✗ SUFeedURL is in Info.plist — Sparkle keys must not ship on MAS." >&2
  exit 1
fi
if ! codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "com.apple.security.app-sandbox"; then
  echo "✗ App Sandbox entitlement missing from $APP" >&2
  exit 1
fi
if ! /usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeName" \
  "$APP/Contents/Info.plist" >/dev/null 2>&1; then
  echo "✗ CFBundleDocumentTypes needs CFBundleTypeName — App Store Connect rejects the" >&2
  echo "  upload with ITMS-90243 otherwise." >&2
  exit 1
fi

echo "✅ $APP"
echo "   Sandboxed, no Sparkle. Drive a link without touching /Applications:"
echo "     open -a \"$APP\" \"https://example.com/mas-test\""
