#!/usr/bin/env bash
# Build a styled, signed, universal BrowBro.dmg from the current source.
# Signing identity/team come from project.yml (an Apple Development cert).
set -euo pipefail
cd "$(dirname "$0")/../.."

DD="${DD:-build/dmg-release}"
OUT="${1:-build/BrowBro.dmg}"

echo "▶ Generating project + building Release…"
xcodegen generate >/dev/null
xcodebuild -project BrowBro.xcodeproj -scheme BrowBro -configuration Release \
  -derivedDataPath "$DD" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -quiet

export BB_APP="$DD/Build/Products/Release/BrowBro.app"
export BB_BACKGROUND="packaging/dmg/background.tiff"

echo "▶ Building DMG…"
rm -f "$OUT"
dmgbuild -s packaging/dmg/dmgbuild-settings.py "BrowBro" "$OUT"
echo "✅ $OUT"
