# Private Windows are derived, opt-in Launch Targets

Users want links to open in an incognito/private window of a chosen browser. We modeled
this as a **variant Launch Target** (a separate picker entry per browser or Chrome
profile), not a pick-time modifier key, because the flat target catalog already gives every
entry a digit, position, visibility, remember-last, and default-target semantics for free —
and a modifier would collide with the existing Trigger Modifier ("hold to summon"), which
gates *whether* the picker appears, never *how* a pick behaves.

## Consequences

- **Derived, never persisted.** Variants are regenerated at discovery with deterministic
  ids `private:<base-id>` (e.g. `private:app:com.google.Chrome`,
  `private:chrome:Profile 1`). They exist only while (a) the master "Private Windows"
  switch is on and (b) the base target is in the per-target opt-in set. Uninstalling the
  browser or toggling off removes them; saved order/default/last-used ids dangle harmlessly
  (existing fallbacks cover this). The id scheme is effectively frozen — it is written into
  users' persisted preferences.
- **Capability table, not universal.** Only browsers with a known private-window launch
  flag offer the variant: Chromium family `--incognito`, Edge `--inprivate`, Opera
  `--private`, Firefox family `--private-window`. Safari is excluded — it has no
  programmatic path short of Accessibility-permission UI scripting, and a privacy feature
  that silently opens a normal window would destroy trust. Adding a browser = adding a
  table row.
- **Direct binary invocation, not NSWorkspace.** Launch flags are only honored as process
  arguments, and these browsers dedupe to their running instance (verified live against a
  running Chrome: `--profile-directory="Profile 1" --incognito <url>` → "Opening in
  existing browser session."). This extends the pattern `openInChrome` already established
  for `--profile-directory`.
- **Chrome profiles compose.** An incognito window belongs to a profile (extensions,
  enterprise policy), so a Private Window variant of a specific Chrome Profile launches
  `--profile-directory=X --incognito` deterministically; a browser-level Chrome variant
  inherits the last-active profile.
- **Firefox verified on macOS.** The historic "already open" failure when invoking the
  binary against a running instance is gone: on Firefox 152, `firefox --private-window
  <url>` forwards to the running instance and exits in <1s, and a cold start opens straight
  into a private window. (Binary name comes from `CFBundleExecutable`, not a hardcoded
  path — Firefox's is `firefox`, Chrome's is `Google Chrome`.)
- **Naming uses each browser's dialect** ("Chrome Incognito", "Edge InPrivate", "Firefox
  Private") because names must be unique in name-only dropdowns and users recognize their
  browser's own word; the canonical domain term stays **Private Window** (CONTEXT.md).
