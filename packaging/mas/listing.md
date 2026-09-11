# App Store Connect — paste-ready listing

All listing copy, screenshots, and review notes are **English (U.S.)** only.
Bundle ID `cloud.tiagomoraes.browbro` · SKU `browbro` · Category **Utilities** (secondary: Productivity).
Price: **Free**. Availability: all territories.

Privacy policy: `https://browbro.tiagomoraes.cloud/privacy`
Support URL: `https://browbro.tiagomoraes.cloud`
Marketing URL: `https://browbro.tiagomoraes.cloud`

The privacy page lives in `site/privacy/` and only goes live when `site/` is on `main`.

---

## Name

```
BrowBro
```

## Subtitle (≤ 30 characters)

```
Every link, your call.
```

## Promotional text (≤ 170 characters, editable without a new binary)

```
Click a link, pick a browser or Chrome profile at your cursor. Keyboard-first, native, local-only. Every link, your call.
```

## Description

```
BrowBro is a tiny macOS menu-bar app that becomes your default browser — then gets out of the way. The instant you click a link, a picker appears at your cursor. Choose a browser, or the right Chrome profile, with the keyboard or the mouse.

It does not render web pages. It routes the URL to an app you already have: Safari, Chrome, Firefox, Edge, or a specific Chrome profile.

WHAT YOU GET

• A picker at the cursor, not a window you have to hunt for
• Keyboard-first: 1–9, first-letter jump, arrows, Enter, Esc
• Chrome profiles as first-class targets (name, color, optional email)
• Optional private / incognito entries per browser or profile
• Hold a modifier to pick; let a plain click go straight to your default
• Reversible default-browser takeover — restore the previous browser any time
• Launch at login so the picker is instant
• Menu-bar only: no Dock icon, no main window

TRUST

BrowBro runs entirely on your Mac. Links are not uploaded. Chrome profile names are read from Chrome’s local files only after you grant that folder in an open panel, and never leave the device. Open source (MIT).

Requires macOS 14 Sonoma or later.
```

## Keywords (≤ 100 characters, no spaces after commas)

```
browser,chrome,profile,picker,link,safari,firefox,edge,default,chooser,router,menubar
```

(84 characters)

## What's New (first MAS version)

```
First release on the Mac App Store. Native menu-bar browser picker for macOS 14+.
```

---

## App Review notes

Paste into the “Notes” field of the version. Reviewers often have not seen a browser *picker*.

```
BrowBro is not a web browser and does not render pages. It registers as the default http(s) handler (CFBundleURLTypes) and forwards each URL to a browser the user already has installed.

HOW TO TEST

1. Open BrowBro from the menu bar (unibrow glyph) → Settings.
2. Click “Set as default”. Confirm the system prompt.
3. Click a link in Notes or Mail, or run:
   open -a BrowBro "https://example.com"
   A picker should appear at the cursor. Esc cancels; Enter / click opens the highlighted browser.
4. Chrome profiles (optional): Settings → Chrome profiles → Grant access… and select
   ~/Library/Application Support/Google/Chrome
   (the folder that contains “Local State”). Profiles then appear in the picker.
5. Private windows: Settings → Private windows → enable, then opt in a browser. The extra picker rows launch that browser’s incognito/private flag.

The app is an LSUIElement menu-bar accessory — no Dock icon. If it looks like nothing launched, look in the menu bar.

It does not include Sparkle or any custom updater. Updates are App Store only.
It does not include donation / tip links.

Sandbox: user-selected read-only access to the Chrome folder the user picks, persisted as an app-scoped bookmark. No Full Disk Access, no temporary exception entitlements.
```

---

## App Privacy (nutrition label)

Data collected? **No.**

Chrome profile names, emails, and recent URLs stay on device. They are not used for tracking, advertising, or analytics. There is no account, no crash reporter, no third-party SDK.

If Connect forces a category because of UserDefaults: **Product Personalization** / **App Functionality**, not linked to identity, not used for tracking. Prefer answering **No data collected** if the form allows it (on-device prefs only).

## Age rating

All **None** / **No**. Expected rating **4+**.

## Export compliance

Uses only HTTPS via the system (opening URLs in other apps).  
`ITSAppUsesNonExemptEncryption` is already `false` in `Resources/Info-MAS.plist`.  
Answer: **No** (exempt encryption).

## Accessibility nutrition label

Leave blank unless you want to declare: keyboard navigation (picker is fully keyboard-driven), Dark Mode (follows system). Do not claim VoiceOver, Larger Text, or Captions — those are not tested as a product promise.

---

## Screenshots (2560×1600, English, fictional UI)

Source: `packaging/mas/screenshots/mock.html`. Render with `packaging/mas/render-screenshots.sh`
(authored at 1280×800 CSS px, rendered at dpr 2 — text is drawn at 2×, never upscaled).
Fictional catalog only (Work / Personal / Design / Client, Safari, Firefox, Edge) and
`example.com` accounts — never a capture of a real machine.

Upload in this order. The first frame is the one most people ever see, so it leads with
the whole product in one picture.

| # | File | Headline | What it has to land |
|---|------|----------|---------------------|
| 1 | `01-hero.png` | Every link, your call. | The picker popping at the cursor over a real desktop |
| 2 | `02-profiles.png` | Work or personal. One key each. | Chrome profiles are first-class targets |
| 3 | `03-keys.png` | One key. Done. | Keyboard-first: 1–9, Return, Esc |
| 4 | `04-private.png` | Private, on purpose. | Incognito twins, and why Safari has none |
| 5 | `05-modifier.png` | One browser, unless I say. | Plain click passes through; ⌥-click asks |
| 6 | `06-trust.png` | Undo it anytime. | The takeover is announced and reversible |
| 7 | `07-catalog.png` | Your list. Your order. | Hide and reorder targets in Settings |
| 8 | `08-privacy.png` | Nothing leaves your Mac. | Local-only routing, no account, MIT |

Every frame shares one grid: 84px margins, copy block at y=150, h1 at 68px (82 on the
hero), secondary block at y=540, and one picker scale (`--k:1.5`) across the set.
Open any frame with `?audit=1` to unclip it and draw the real 1280×800 boundary — that
is how you catch a block running past an edge before it ships.

Screenshot slots hold ten; eight is the set. Frames 1–3 carry the pitch on their own if a
viewer never swipes.

## App preview (optional, up to 3)

`packaging/mas/previews/01-every-link.mp4` — **1920×1080, 16:9**, 17.6s, 30fps, H.264 High
4.0, silent stereo AAC track. Built by `packaging/mas/render-preview.sh` from
`previews/preview.html`.

Previews are **not** the same shape as screenshots: Connect takes macOS previews only at
1920×1080 landscape, 15–30 seconds. A 2560×1600 file is rejected.

Seven acts, one continuous story: title card → a link on the desktop → the picker appears
at the cursor → press 2 → the Personal profile opens → profiles as targets → end card.
The default poster frame (5s) lands on the picker, which is the frame worth freezing.
