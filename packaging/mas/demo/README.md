# App Review demo recording

App Review's Guideline 2.1 questionnaire asks for a screen recording "captured on a
physical device, running the latest operating system", that **begins with launching
the app** and shows the typical flow. See `docs/MAS.md` for why the Mac gets staged.

```sh
packaging/mas/build-mas.sh          # the sandboxed BrowBroMAS build
packaging/mas/demo/setup.sh         # stage: hide other copies, fresh container, Chrome as default
# …record (below)…
packaging/mas/demo/build-video.sh   # → build/review/browbro-app-review.mp4
packaging/mas/demo/teardown.sh      # put everything back
```

## Shot list (about a minute and a half)

Before recording: close unrelated windows, open `~/Applications` in Finder, and open
`~/Library/Caches/browbro-demo/Links.rtf` in TextEdit behind it. `setup.sh` stashes the
launch helper, so its install prompt shows on camera.

1. **⌘⇧5 → Record Entire Screen → Record.**
2. Finder → double-click **BrowBro**. The welcome window opens ("Currently: Google Chrome").
3. **Set BrowBro as default browser** → in the macOS panel, **Use "BrowBro"** → Done.
4. Click the unibrow glyph in the menu bar: no Dock icon, no main window.
5. TextEdit → click the first link → the picker opens at the pointer → **Safari**.
6. TextEdit → second link → press Chrome's number key (or arrows + Return).
7. Menu bar glyph → **Settings** → Chrome profiles → **Grant access…** → ⌘⇧G →
   `~/Library/Application Support/Google/Chrome` → Grant Access. The profiles and the
   "Install the launch helper" row appear.
8. TextEdit → third link → a **Chrome profile** row → the launch-helper save panel →
   **Install** → the link opens in that profile.
9. Settings → **Private windows** → on, then opt Chrome in.
10. Fourth link → **Google Chrome Incognito** → an incognito window opens.
11. Click any link → **Esc** → nothing opens.
12. Stop the recording (⏹ in the menu bar).

## Driving it by script

The 2026-11-02 take was recorded without hands on the Mac: one ffmpeg segment per step
(`-f avfoundation -i "Capture screen 0" -capture_mouse_clicks 1`, stopped with SIGINT),
clicks posted as CGEvents at positions read from the accessibility tree, and the
segments joined with `build-video.sh 01.mkv 02.mkv …`. Things that bit:

- Disconnect any DevTools client first, or Chrome shows "Chrome is being controlled by
  automated test software" on camera.
- The welcome window drops behind Finder once the default-browser panel closes;
  re-activate BrowBro before the next segment.
- The first click on an inactive TextEdit window only focuses it; it doesn't follow the link.
- The open panel runs out of process and its controls aren't in BrowBro's AX tree.
  Synthetic Unicode typing doesn't reach it either: ⌘⇧G, then paste the path.
