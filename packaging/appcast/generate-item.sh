#!/usr/bin/env bash
#
# Print a Sparkle appcast <item> for a built BrowBro DMG, ready to paste at the
# top of the <channel> in site/appcast.xml. Signs the DMG with the EdDSA private
# key from your login keychain (see docs/UPDATES.md).
#
# It refuses a DMG that would make a wrong item, before anything is signed:
#   - one that isn't notarized and stapled. The item pins this file's exact
#     length and signature, and stapling rewrites the file, so an item made from
#     anything but notarize-release.sh's finished output describes bytes that
#     aren't the ones on the release — and every install refuses the update.
#   - one whose app disagrees with project.yml. The item's version numbers come
#     from project.yml, so a stale DMG would go out labelled as the new release;
#     and Sparkle installs an update only over an app with its bundle id.
#
# Usage:
#   packaging/appcast/generate-item.sh build/BrowBro.dmg
#
set -euo pipefail
cd "$(dirname "$0")/../.."

DMG="${1:-build/BrowBro.dmg}"
[ -f "$DMG" ] || { echo "error: DMG not found: $DMG" >&2; exit 1; }

REPO_URL="https://github.com/tiagomoraes/browbro"

# Versions come from the single source of truth, project.yml: the BrowBro
# target's own setting where it has one, else the project-wide base. A plain
# grep for the first MARKETING_VERSION can't tell the BrowBro target's from
# BrowBroMAS's; scripts/project-yml.sh reads the structure.
setting() { scripts/project-yml.sh "targets.BrowBro.settings.base.$1" "settings.base.$1"; }
SHORT=$(setting MARKETING_VERSION)
BUILD=$(setting CURRENT_PROJECT_VERSION)
BUNDLE_ID=$(setting PRODUCT_BUNDLE_IDENTIFIER)
MIN_MACOS=$(scripts/project-yml.sh targets.BrowBro.deploymentTarget options.deploymentTarget.macOS)
URL="${REPO_URL}/releases/download/v${SHORT}/BrowBro.dmg"
PUBDATE=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')

# --- Notarized and stapled, or no item ---------------------------------------
# The same two checks notarize-release.sh ends on. spctl also has to name the
# source: with Gatekeeper switched off it "accepts" anything.
if ! out=$(xcrun stapler validate "$DMG" 2>&1); then
  echo "error: $DMG has no stapled notarization ticket:" >&2
  printf '%s\n' "$out" | sed 's/^/  /' >&2
  echo "  Build release DMGs with packaging/notarize/notarize-release.sh (docs/NOTARIZING.md)." >&2
  exit 1
fi
if ! out=$(spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1) ||
   ! grep -q "source=Notarized Developer ID" <<<"$out"; then
  echo "error: Gatekeeper does not accept $DMG as notarized:" >&2
  printf '%s\n' "$out" | sed 's/^/  /' >&2
  exit 1
fi

# --- The app inside agrees with project.yml ----------------------------------
MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/browbro-appcast.XXXXXX")
detach() {
  hdiutil detach "$MOUNT" -quiet 2>/dev/null || hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true
  rmdir "$MOUNT" 2>/dev/null || true
}
trap detach EXIT
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$MOUNT" "$DMG" >/dev/null ||
  { echo "error: could not mount $DMG to read its app. Already open in Finder? Eject it and retry." >&2; exit 1; }
INFO="$MOUNT/BrowBro.app/Contents/Info.plist"
[ -f "$INFO" ] || { echo "error: no BrowBro.app at the top of $DMG" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$INFO" 2>/dev/null || echo "(missing)"; }
APP_SHORT=$(plist CFBundleShortVersionString)
APP_BUILD=$(plist CFBundleVersion)
APP_ID=$(plist CFBundleIdentifier)
detach
trap - EXIT

if [ "$APP_SHORT" != "$SHORT" ] || [ "$APP_BUILD" != "$BUILD" ]; then
  echo "error: $DMG holds BrowBro $APP_SHORT ($APP_BUILD), but project.yml says $SHORT ($BUILD)." >&2
  echo "  Rebuild the DMG from this checkout, or check out the commit it was built from." >&2
  exit 1
fi
if [ "$APP_ID" != "$BUNDLE_ID" ]; then
  echo "error: $DMG holds $APP_ID, but project.yml's bundle id is $BUNDLE_ID." >&2
  echo "  Sparkle only installs an update over an app with the same bundle id." >&2
  exit 1
fi

# --- Sign -----------------------------------------------------------------------
SIGN_UPDATE="build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
if [ ! -x "$SIGN_UPDATE" ]; then
  echo "error: sign_update not found. Run first:" >&2
  echo "  xcodebuild -project BrowBro.xcodeproj -scheme BrowBro -resolvePackageDependencies -derivedDataPath build" >&2
  exit 1
fi
# sign_update prints:  sparkle:edSignature="…" length="…"
SIG_ATTRS=$("$SIGN_UPDATE" "$DMG")

# Release notes: the CHANGELOG section for this version, rendered to simple HTML.
# Matches the "## [x.y.z]" heading literally (index, not regex — the dots in a
# version would otherwise be wildcards), reflows wrapped bullet lines, then turns
# **bold** and [text](url) into HTML. A relative link means a file in this repo,
# which resolves against nothing inside Sparkle's release-notes view, so it is
# pointed at GitHub instead (0.1.4's docs/UPDATES.md link went nowhere).
NOTES=$(awk -v head="## [$SHORT]" '
  index($0, head) == 1 { grab = 1; next }
  grab && /^## \[/ { exit }
  grab { print }
' CHANGELOG.md | awk '
  function flush() { if (item != "") { print "<li>" item "</li>"; item = "" } }
  /^### / { flush(); if (ul) { print "</ul>"; ul = 0 }
            h = $0; sub(/^### /, "", h); print "<h4>" h "</h4>"; next }
  /^- /   { flush(); if (!ul) { print "<ul>"; ul = 1 }
            item = $0; sub(/^- /, "", item); next }
  /^[[:space:]]*$/ { next }
  { line = $0; sub(/^[[:space:]]+/, "", line); item = item " " line }   # wrapped line
  END { flush(); if (ul) print "</ul>" }
' | sed -E \
    -e 's/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g' \
    -e 's/\[([^]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g' \
    -e 's|<a href="\./|<a href="|g' \
    -e 's|<a href="/([^/"][^"]*)"|<a href="'"$REPO_URL"'/blob/main/\1"|g' \
    -e 's|<a href="([^"/:#][^":]*)"|<a href="'"$REPO_URL"'/blob/main/\1"|g')

cat <<EOF
    <item>
      <title>Version ${SHORT}</title>
      <link>${REPO_URL}/releases/tag/v${SHORT}</link>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${SHORT}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_MACOS}</sparkle:minimumSystemVersion>
      <pubDate>${PUBDATE}</pubDate>
      <description><![CDATA[
${NOTES}
      ]]></description>
      <enclosure url="${URL}"
                 ${SIG_ATTRS}
                 type="application/x-apple-diskimage" />
    </item>
EOF
