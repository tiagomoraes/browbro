---
name: verify
description: Build, install, and drive BrowBro to observe a change at its real surface (picker, launches). Use when verifying that a code change works end-to-end.
---

# Verifying BrowBro changes

## Build + install + launch

`./build.sh` — xcodegen + xcodebuild + install to /Applications + relaunch. This is the
whole handle; there is no test target.

## Back up prefs first

Verification usually means mutating prefs. Snapshot and restore exactly:

```bash
defaults export so.aca.browbro /tmp/browbro-prefs-backup.plist
# … drive …
defaults delete so.aca.browbro && defaults import so.aca.browbro /tmp/browbro-prefs-backup.plist
```

## Drive a link WITHOUT changing the default browser

```bash
open -a BrowBro "https://example.com/my-test"
```

The picker pops at the cursor. Dismiss without launching by activating another app
(`osascript -e 'tell application "Finder" to activate'`).

## Drive a launch with NO UI interaction

Modifier mode opens `defaultTargetID` directly on a plain link — a programmatic path
through `BrowserLauncher.launch`:

```bash
defaults write so.aca.browbro requireModifierForPicker -bool true
defaults write so.aca.browbro defaultTargetID "app:com.google.Chrome"   # any target id
open -a BrowBro "https://example.com/launch-test"
```

## Observe

- **Decisions**: `/usr/bin/log show --last 5m --info --predicate 'subsystem == "so.aca.browbro"'`
  — the picker logs presented targets and which target a launch resolved to. Use the full
  path (`log` is a zsh builtin) and remember `--info`.
- **Pixels**: `screencapture -x /tmp/shot.png` then Read the image. Fails silently to a
  lock-screen shot if the screen locked mid-run — check what you captured.
- **Window titles** (works even when AppleScript to Chrome times out — it does when a
  devtools-automation Chrome instance is around): CGWindowList via a scratch Swift script;
  Chrome's owner name is "Google Chrome", Firefox's is "Firefox". Firefox private windows
  are titled "… — Private Browsing".
- **Incognito proof**: incognito writes no history. Copy the profile's
  `~/Library/Application Support/Google/Chrome/<Profile>/History` and
  `sqlite3 … "SELECT count(*) FROM urls WHERE url LIKE '%my-test%'"` — 0 hits while the
  window exists is the signature.

## Gotchas

- Target ids: `app:<bundleID>`, `chrome:<profile dir>`, `private:<base-id>`.
- `defaults write` while BrowBro runs is fine — the catalog refreshes on every link.
- Debug build replaces the installed app; that's the sanctioned dev loop.
