#!/usr/bin/env bash
# Build a styled, universal BrowBro DMG from the current source: a LOCAL PREVIEW
# of the window layout and background, nothing more.
#
# NEVER PUBLISH IT. The app inside is signed with the Apple Development identity
# from project.yml and nothing is notarized, so Gatekeeper blocks it on any Mac
# but this one. Release DMGs come from packaging/notarize/notarize-release.sh
# (docs/NOTARIZING.md).
#
# It writes build/BrowBro-preview.dmg, never build/BrowBro.dmg: that path is the
# release script's output and the appcast script's default input, and a preview
# left there would be one upload away from shipping.
#
# Usage: packaging/dmg/build-dmg.sh [out.dmg]
set -euo pipefail
cd "$(dirname "$0")/../.."

DD="${DD:-build/dmg-release}"
OUT="${1:-build/BrowBro-preview.dmg}"

echo "▶ Generating project + building Release…"
xcodegen generate >/dev/null
xcodebuild -project BrowBro.xcodeproj -scheme BrowBro -configuration Release \
  -derivedDataPath "$DD" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -quiet

export BB_APP="$DD/Build/Products/Release/BrowBro.app"
export BB_BACKGROUND="packaging/dmg/background.tiff"

echo "▶ Building DMG…"
rm -f "$OUT"
dmgbuild -s packaging/dmg/dmgbuild-settings.py "BrowBro" "$OUT"
echo "✅ $OUT — local preview only, not notarized; never publish it."
