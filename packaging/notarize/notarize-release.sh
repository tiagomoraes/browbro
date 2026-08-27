#!/usr/bin/env bash
#
# Build a SIGNED, NOTARIZED, stapled, universal BrowBro.dmg.
# Produces a build Gatekeeper accepts on first launch — no "Open Anyway" detour.
#
# One-time prerequisites (all already done for this repo — see docs/NOTARIZING.md):
#   1. Apple Developer Program membership (paid).
#   2. A "Developer ID Application" certificate in your login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   3. notarytool credentials stored as a keychain profile, e.g.:
#        xcrun notarytool store-credentials browbro-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" \
#          --password "APP-SPECIFIC-PASSWORD"     # appleid.apple.com > App-Specific Passwords
#   4. dmgbuild on PATH (pipx install dmgbuild — Homebrew Pythons refuse a bare pip install).
#
# Usage:
#   packaging/notarize/notarize-release.sh [out.dmg]
#
# DEVELOPER_ID is auto-detected from the keychain and NOTARY_PROFILE defaults to
# "browbro-notary"; both can still be overridden by environment variable.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Auto-detect the Developer ID rather than making every release retype it — a
# typo here is the difference between a notarized build and the unsigned one.
if [ -z "${DEVELOPER_ID:-}" ]; then
  DEVELOPER_ID=$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
fi
: "${DEVELOPER_ID:?No 'Developer ID Application' identity in the keychain — see docs/NOTARIZING.md}"
NOTARY_PROFILE="${NOTARY_PROFILE:-browbro-notary}"

DD="${DD:-build/notarize-release}"
OUT="${1:-build/BrowBro.dmg}"
ENTITLEMENTS="packaging/notarize/BrowBro.entitlements"

echo "▶ Signing identity: $DEVELOPER_ID"

# Submit $1 to Apple, wait, and staple the ticket onto $2 (default: $1). The two
# differ for the app bundle: notarytool only takes an archive, but `stapler`
# refuses a zip, so the ticket has to land on the bundle the zip was made from.
#
# Submitting and stapling live in one function because separating them is how
# v0.1.6 went out unsigned: Apple accepted it, the run died before the staple,
# and an accepted-but-unstapled artifact looks exactly like an unsigned one.
notarize_and_staple() {
  local artifact="$1" target="${2:-$1}" log id
  log=$(mktemp)
  if ! xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" \
       --wait 2>&1 | tee "$log" || ! grep -q "status: Accepted" "$log"; then
    id=$(sed -n 's/^  *id: \([0-9a-f-]*\)$/\1/p' "$log" | head -1)
    echo "✗ Notarization failed for $artifact. Submission: ${id:-unknown}" >&2
    [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2
    return 1
  fi
  xcrun stapler staple "$target"
  xcrun stapler validate "$target"
}

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

# Notarize the app on its own, so the copy the user drags to /Applications —
# and the copy Sparkle extracts on an in-place update — carries its own ticket.
# The DMG's ticket does not travel with the app that comes out of it.
echo "▶ Notarizing the app (a few minutes)…"
APP_ZIP="$(dirname "$APP")/BrowBro-notarize.zip"
rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP" "$APP_ZIP"   # preserves the framework's symlinks
notarize_and_staple "$APP_ZIP" "$APP"        # submit the zip, staple the bundle
rm -f "$APP_ZIP"

echo "▶ Building styled DMG…"
export BB_APP="$APP" BB_BACKGROUND="packaging/dmg/background.tiff"
rm -f "$OUT"
dmgbuild -s packaging/dmg/dmgbuild-settings.py "BrowBro" "$OUT"

# Sign the disk image itself, not just the app inside it. Apple's notarization
# workflow expects this, and it means the download is verifiable even before the
# stapled ticket is consulted.
echo "▶ Signing the disk image…"
codesign --force --timestamp --sign "$DEVELOPER_ID" "$OUT"

echo "▶ Notarizing the disk image (a few minutes)…"
notarize_and_staple "$OUT"

# Gatekeeper gate. Nothing ships that doesn't pass here, on both the disk image
# and the app a user actually drags out of it.
echo "▶ Verifying what a downloader will see…"
spctl -a -t open --context context:primary-signature -vv "$OUT"
MOUNT=$(mktemp -d)
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$OUT" >/dev/null
trap 'hdiutil detach "$MOUNT" >/dev/null 2>&1 || true' EXIT
spctl -a -vv "$MOUNT/BrowBro.app"
xcrun stapler validate "$MOUNT/BrowBro.app"

echo "✅ Signed, notarized, stapled: $OUT"
