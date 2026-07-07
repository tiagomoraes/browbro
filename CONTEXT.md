# BrowBro

A macOS menu-bar app that intercepts clicked links and pops a keyboard-first picker at the
cursor, so every link opens in the right browser or Chrome profile.

## Language

**Launch Target**:
A single pickable destination in the Picker.
_Avoid_: browser option, entry, item

**Browser**:
An installed app registered to handle http(s) links.

**Chrome Profile**:
A specific Chrome user profile, pickable as its own Launch Target.
_Avoid_: account, persona

**Private Window**:
A browsing session that persists no history or cookies once closed, opened as a window (the
browser decides tab placement — BrowBro cannot control it).
_Avoid_: anonymous tab, incognito (Chrome-only dialect), private tab, private mode

**Picker**:
The keyboard-first popover listing Launch Targets when a link is clicked.

**Trigger Modifier**:
The key held to summon the Picker when plain clicks bypass it — it gates *whether* the
Picker appears, never *how* a pick behaves.
_Avoid_: hotkey, shortcut

## Relationships

- The **Picker** lists **Launch Targets** in the user's saved order.
- A **Launch Target** is a **Browser**, a **Chrome Profile**, or a **Private Window** variant
  of either.
- Only Browsers with a known private-window capability (and their Chrome Profiles) offer a
  **Private Window** variant; Safari offers none.

## Example dialogue

> **Dev:** "When someone picks the **Private Window** target, do we open a tab in an
> existing incognito window?"
> **Domain expert:** "We ask the **Browser** for a **Private Window**; whether it reuses an
> open one and adds a tab is the browser's call, not ours."

## Flagged ambiguities

- "anonymous tab" was used to mean **Private Window** — resolved: it is a window-level
  concept and named vendor-neutrally; per-browser UI copy may still use the browser's own
  dialect (e.g. "Incognito" for Chrome).
