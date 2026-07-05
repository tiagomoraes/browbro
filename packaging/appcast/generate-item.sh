#!/usr/bin/env bash
#
# Print a Sparkle appcast <item> for a built BrowBro DMG, ready to paste at the
# top of the <channel> in site/appcast.xml. Signs the DMG with the EdDSA private
# key from your login keychain (see docs/UPDATES.md).
#
# Usage:
#   packaging/appcast/generate-item.sh build/BrowBro.dmg
#
set -euo pipefail
cd "$(dirname "$0")/../.."

DMG="${1:-build/BrowBro.dmg}"
[ -f "$DMG" ] || { echo "error: DMG not found: $DMG" >&2; exit 1; }

SIGN_UPDATE="build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
if [ ! -x "$SIGN_UPDATE" ]; then
  echo "error: sign_update not found. Run first:" >&2
  echo "  xcodebuild -project BrowBro.xcodeproj -scheme BrowBro -resolvePackageDependencies -derivedDataPath build" >&2
  exit 1
fi

# Versions come from the single source of truth, project.yml.
SHORT=$(awk -F'"' '/MARKETING_VERSION:/{print $2; exit}' project.yml)
BUILD=$(awk -F'"' '/CURRENT_PROJECT_VERSION:/{print $2; exit}' project.yml)
URL="https://github.com/tiagomoraes/browbro/releases/download/v${SHORT}/BrowBro.dmg"
PUBDATE=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')

# sign_update prints:  sparkle:edSignature="…" length="…"
SIG_ATTRS=$("$SIGN_UPDATE" "$DMG")

# Release notes: the CHANGELOG section for this version, rendered to simple HTML.
# Matches the "## [x.y.z]" heading literally (index, not regex — the dots in a
# version would otherwise be wildcards), reflows wrapped bullet lines, then turns
# **bold** and [text](url) into HTML.
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
    -e 's/\[([^]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')

cat <<EOF
    <item>
      <title>Version ${SHORT}</title>
      <link>https://github.com/tiagomoraes/browbro/releases/tag/v${SHORT}</link>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${SHORT}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>${PUBDATE}</pubDate>
      <description><![CDATA[
${NOTES}
      ]]></description>
      <enclosure url="${URL}"
                 ${SIG_ATTRS}
                 type="application/x-apple-diskimage" />
    </item>
EOF
