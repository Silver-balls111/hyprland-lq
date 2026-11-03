# Memory profile & lazy popups

Read this before changing how popups are created/destroyed, or the
autostart memory settings in `~/.config/hypr/config/autostart.lua`.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Memory profile + lazy popups (2026-10-06, optimization branch)

Full numbers in [OPTIMIZATIONS.md](../../OPTIMIZATIONS.md); the load-bearing bits:

- **The engine floor is 212 MB** — an EMPTY `ShellRoot {}` config idles at
  212 MB on this machine (Qt + QApplication + Mesa/LLVM + QML engine). Never
  chase idle RSS below that from QML. Renderer is threaded GL (AMD iGPU);
  GPU textures do not appear in RSS — private-dirty anon is JS + QML trees +
  the CPU-side pixmap cache.
- **Popups are lazy now** (`Loader { active: Popups.active === "<name>" }` in
  Bar.qml ×4, StatusPill's TrayMenuPopup, shell.qml Wallswitch — the
  clipboard panel that also lived here has since been removed entirely):
  created when the popup opens, DESTROYED when it closes.
  RicePopup / TrayMenuPopup / Wallswitch all sync initial visibility from
  `Popups.active` in `Component.onCompleted`, so being created mid-open
  works. Two designs were tried and REJECTED — do not retry: (1) a latch
  binding (`active: everOpened || …` + write-back in `onActiveChanged`) is a
  **QML binding loop** ("Binding loop detected for property active"); (2) an
  imperative latch (keep the window forever, set active from Connections)
  compiles clean but the **remap is flaky** — after other popup windows had
  mapped/unmapped, a re-shown surface sometimes never appeared at all
  (reproduced 2/14 opens, `hyprctl layers` shows NO surface). Fresh creation
  per open is deterministic; ~ms cost; churn plateaus (~105 KiB/cycle).
- **A Process owned by a lazily destroyed popup dies with it.** The Loader
  synchronously destroys the popup's whole object tree the moment
  `Popups.active` clears — `apply()`/`restore()` started their command and
  closed the popup in the same tick, killing awww/wl-copy before it ran
  (the picker "closed without applying" — the memory pass regression).
  Rule: **fire-and-forget actions never live inside lazy popups** — they
  live in `core/Actions.qml` (persistent singleton, Item root per the
  ScreenTime precedent): `Actions.applyWallpaper(path, trans)`. Processes
  whose results are only consumed while the popup is open stay in the popup.
- **glibc tuning on the launch line** (autostart.lua):
  `MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=8388608` — measured −32 MB and
  caps the RSS ratchet. Remove and RSS drifts back up.
- **`imageSupported: false`** in shell.qml — nothing renders notification
  images; advertising support only made apps ship raw payloads.
- Tested and CLEARED with numbers (do not re-chase): Wallswitch `cache: true`
  accumulation (pixmap cache purges fine), Notifs history retention (scalar
  snapshots only), lockscreen post-unlock retention (surface owns the
  content tree via a Loader), OSD FileView churn (2000 reloads = ±0).
