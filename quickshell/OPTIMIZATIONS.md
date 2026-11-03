# OPTIMIZATIONS.md — memory pass, executed 2026-10-06 (optimization branch)

Status: **executed.** This file is now the record of what was measured, what
was ruled out, and what changed. Re-measure before touching anything below.

## Headline numbers

| Measurement | Before | After |
|---|---|---|
| Fresh idle RSS (`qs -c rice`, everything closed) | ~380 MB | **~322 MB** |
| Used instance after real interaction | ~495 MB within ~15 min of use | capped by glibc env, expect ~330–360 |
| Empty-config engine floor (`ShellRoot {}` alone) | — | **212 MB** (stable plateau over 10 min) |
| Idle surfaces | 1 layer group (bar) | 1 layer group (bar) |

**The floor is the story**: an *empty* Quickshell 0.3.1 config idles at
212 MB on this machine (Qt + QApplication + Mesa/LLVM mappings + QML engine).
No QML-side work can go below that. Of the old ~380 MB fresh, ~170 MB was
config; this pass removed ~58 MB of it and capped the growth ratchet.

## What was measured (Phase 0 + suspect tests — all numbers reproducible)

- Process composition (smaps): ~285 MB of the old 506 MB was private-dirty
  anonymous heap (CPU-side: JS, QML trees, decoded-QImage pixmap cache,
  Canvas surfaces); ~115 MB was shared Mesa/LLVM mappings. Renderer is the
  threaded GL scene graph (AMD iGPU) — GPU textures do NOT show up in RSS.
- **Engine floor**: `ShellRoot {}` → 212 MB, flat over 10 min. Every
  measurement above the floor is config cost.
- **Wallswitch browsing does NOT accumulate** — 120 centered wallpapers in a
  throwaway: RSS **−29 MB** (Qt's pixmap cache purges unreferenced entries
  fine, even with `cache: true` on the slot Images).
- **Notification history does NOT accumulate** — `Notifs.push` snapshots
  scalar fields only; no hint/image payloads retained; live `Notification`
  wrappers dropped when their toast ends.
- **Lockscreen does NOT retain memory after unlock** — the wallpaper Image +
  blur MultiEffect live inside a Loader that is a child of
  `WlSessionLockSurface`; the surface is destroyed on unlock and takes the
  whole content tree with it. (At most one ~10 MB wallpaper pixmap lingers
  in Qt's trimmable pixmap cache.)
- **OSD FileView poll churn is free** — 2000 `FileView.reload()` calls at
  40 ms: RSS flat (±0). The 400 ms brightness poll costs nothing.
- **Popup open/close cycles plateau, not leak** — eager build: +26 MB over
  the first ~50 cycles (engine warm-up: glyph caches, JS caches), then flat
  (~76 KiB/cycle average over 250).

## What changed

1. **Popups are created on demand and destroyed on close**
   (`bar/Bar.qml` ×4, `bar/StatusPill.qml` tray menu, `shell.qml`
   Wallswitch (ClipboardPopup has since been removed entirely) — plain
   `Loader { active: Popups.active ===
   "name" }`). An idle shell now carries zero popup trees, and close returns
   that memory. Two designs were tried first and REJECTED — don't retry:
   - *Latch Loader* (`active: everOpened || Popups.active === name` +
     write-back in `onActiveChanged`) → **QML binding loop** ("Binding loop
     detected for property active") — the write re-enters the binding's own
     dependency set.
   - *Imperative latch* (`active: false`, set true from a Connections) → no
     loop, but the kept window's **remap is flaky**: after several other
     popup windows had mapped/unmapped, a re-shown surface sometimes never
     appeared at all (reproduced 2/14 opens; `hyprctl layers` showed NO
     surface). Fresh creation has never failed (dozens of opens) because it
     always takes the first-map path — RicePopup/TrayMenuPopup/Wallswitch
     all sync initial visibility from `Popups.active` in their
     `Component.onCompleted`.
   Cost: re-instantiation per open (~ms; the engine caches compiled
   components) and a churn plateau slightly above remap's (~105 vs
   ~76 KiB/cycle average, warm-up-dominated, measured over 250 cycles).
   Verified: full popup tour ×2 with pixel scans — every open rendered.
2. **glibc allocator tuning** in `~/.config/hypr/config/autostart.lua`:
   `MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=8388608` on the `qs` launch
   line. Measured −32 MB on the identical config (383 → 351) and it caps the
   RSS ratchet (glibc otherwise keeps freed heap per-arena).
3. **`imageSupported: false`** in shell.qml's NotificationServer — nothing
   in the shell renders notification images, so advertising support only
   made apps ship raw image payloads for nothing.

## Suspects tested and CLEARED (do not re-chase)

Wallswitch `cache: true` growth · Notifs image payloads · lockscreen
post-unlock retention · OSD FileView churn · fullscreen shields at idle
(unmapped windows hold no buffers — 1 layer group at idle) · notification
history size.

## Revised target & remaining levers

- Realistic floor: **~322 MB fresh idle** (212 engine + ~110 config). The
  old "< 200 MB" target is impossible on Quickshell 0.3.1 — an empty config
  already costs 212.
- Watch the idle curve (`while :; do printf '%s %s\n' "$(date +%T)"
  "$(ps -o rss= -C qs)"; sleep 30; done`): with the env caps, growth should
  plateau; a steady climb beyond ~400 MB with zero interaction would be a
  new leak worth a heaptrack session.
- If further wins are ever needed, the next lever is shrinking the config
  side of the ~110 MB (smaller at-open trees), not the engine floor.
