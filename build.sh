#!/usr/bin/env bash
#
# Local dev build for BrowBro (Decision 7: unsigned/ad-hoc, no notarization).
# Generates the Xcode project from project.yml, builds, registers the app with
# LaunchServices, and launches it.
#
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Build/Products/Debug/BrowBro.app"

echo "▶ Generating Xcode project (xcodegen)…"
xcodegen generate

echo "▶ Building…"
xcodebuild \
  -project BrowBro.xcodeproj \
  -scheme BrowBro \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
  -quiet

echo "▶ Registering with LaunchServices…"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$APP"

echo "▶ Launching BrowBro…"
open "$APP"

cat <<'EOF'

✅ BrowBro is running (look for the ↗ icon in the menu bar).

Prove link reception WITHOUT changing your default browser:
    open -a BrowBro "https://example.com/it-works"

Then open the menu-bar item — the URL should appear under "Last received link".
EOF
