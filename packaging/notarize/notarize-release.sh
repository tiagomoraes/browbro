#!/usr/bin/env bash
#
# Build a NOTARIZED, stapled, universal BrowBro.dmg.
# Produces a build Gatekeeper accepts with no "Open Anyway" step.
#
# One-time prerequisites:
#   1. Apple Developer Program membership (paid).
#   2. A "Developer ID Application" certificate in your login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   3. notarytool credentials stored as a keychain profile, e.g.:
#        xcrun notarytool store-credentials browbro-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" \
#          --password "APP-SPECIFIC-PASSWORD"     # appleid.apple.com > App-Specific Passwords
#      (or --key / --key-id / --issuer for an App Store Connect API key)
#   4. pip install dmgbuild
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="browbro-notary" \
#   packaging/notarize/notarize-release.sh [out.dmg]
set -euo pipefail
cd "$(dirname "$0")/../.."

: "${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application: … (TEAMID)' identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile (see header)}"

DD="${DD:-build/notarize-release}"
OUT="${1:-build/BrowBro.dmg}"
ENTITLEMENTS="packaging/notarize/BrowBro.entitlements"

echo "▶ Building Release (Developer ID, hardened runtime)…"
xcodegen generate >/dev/null
xcodebuild -project BrowBro.xcodeproj -scheme BrowBro -configuration Release \
  -derivedDataPath "$DD" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  PROVISIONING_PROFILE_SPECIFIER="" ENABLE_HARDENED_RUNTIME=YES -quiet

APP="$DD/Build/Products/Release/BrowBro.app"

echo "▶ Re-signing with hardened runtime + secure timestamp…"
# Sparkle ships nested helpers (an updater app + XPC services). They must be
# signed inside-out with the same Developer ID and hardened runtime, or
# notarization rejects them. `--deep` does NOT sign these correctly (Sparkle
# advises against it), so sign each explicitly, innermost first, then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
  SPARKLE_VERSION="$SPARKLE/Versions/Current"
  for nested in \
    "$SPARKLE_VERSION/XPCServices/Downloader.xpc" \
    "$SPARKLE_VERSION/XPCServices/Installer.xpc" \
    "$SPARKLE_VERSION/Autoupdate" \
    "$SPARKLE_VERSION/Updater.app" \
    "$SPARKLE"; do
    [ -e "$nested" ] && codesign --force --options runtime --timestamp \
      --sign "$DEVELOPER_ID" "$nested"
  done
fi
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$DEVELOPER_ID" "$APP"
codesign --verify --strict --deep "$APP"

echo "▶ Building styled DMG…"
export BB_APP="$APP" BB_BACKGROUND="packaging/dmg/background.tiff"
rm -f "$OUT"
dmgbuild -s packaging/dmg/dmgbuild-settings.py "BrowBro" "$OUT"

echo "▶ Notarizing (a few minutes)…"
xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▶ Stapling the ticket…"
xcrun stapler staple "$OUT"
xcrun stapler validate "$OUT"

echo "✅ Notarized + stapled: $OUT"
echo "   Gatekeeper check: spctl -a -t open --context context:primary-signature -vv \"$OUT\""
