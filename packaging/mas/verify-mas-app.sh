#!/usr/bin/env bash
#
# Refuse an App Store build that would be rejected.
#
# Every check here stands for a rejection that has happened, or that the target
# exists to prevent. They run against a built .app — from build-mas.sh locally,
# and from the archive in CI (.github/workflows/app-store.yml) — so the store
# binary is held to the same bar wherever it was produced.
#
# Usage:
#   packaging/mas/verify-mas-app.sh path/to/BrowBro.app
#
set -euo pipefail

APP="${1:?usage: verify-mas-app.sh <path to BrowBro.app>}"
[ -d "$APP" ] || { echo "✗ Not an app bundle: $APP" >&2; exit 1; }

fail() { echo "✗ $1" >&2; exit 1; }

# Guideline 2.4.5(vii): a store app updates through the store. Sparkle in the
# bundle is an automatic rejection, so the framework must not have travelled
# over from the DMG target.
[ -d "$APP/Contents/Frameworks/Sparkle.framework" ] &&
  fail "Sparkle.framework is in the MAS build — it must not ship (2.4.5(vii))."

grep -q SUFeedURL "$APP/Contents/Info.plist" 2>/dev/null &&
  fail "SUFeedURL is in Info.plist — Sparkle keys must not ship on MAS."

# Guideline 2.4.5(i). Also the thing that makes the NSOpenPanel + bookmark path
# in ChromeAccess.swift necessary — without the entitlement we'd be testing a
# code path the store build never takes.
codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "com.apple.security.app-sandbox" ||
  fail "App Sandbox entitlement missing from $APP"

# ITMS-90243, hit for real on the first upload: App Store Connect rejects the
# package if any CFBundleDocumentTypes entry has no CFBundleTypeName.
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeName" \
  "$APP/Contents/Info.plist" >/dev/null 2>&1 ||
  fail "CFBundleDocumentTypes needs CFBundleTypeName — Connect rejects the upload
  with ITMS-90243 otherwise."

echo "✅ $APP passes the App Store checks."
