# OPTIMIZATIONS.md — memory plan (next step after the dir cleanup)

Status: **plan only, not yet executed.** The restructure (2026-10-06) is done
and verified; this file is the backlog for the follow-up performance pass.

## Measured baseline (2026-10-06)

| Measurement | Value |
|---|---|
| Idle RSS, fresh instance (`qs -c rice`, ~4 min uptime) | **~380 MB** (`ps -C qs -o rss=` → 389 064 KB) |
| Idle RSS, long-lived instance (pre-restructure) | ~423 MB, user reports up to **480 MB** |
| Surfaces at idle | 1 quickshell layer group (bar); toast/OSD/tooltip unmapped by design |
| Session | single 1920×1080 output; current wallpaper 2048×1228 (≈10 MB decoded RGBA) |

A Qt Quick + QML config of this complexity should idle far below this — the
 Quickshell/QML engine floor is typically well under 200 MB. Something in the
 config allocates heavily and/or retains decoded images.

**Leak vs steady-state first**: an idle RSS that *grows* over hours is a leak
(unretained image/pixmap cache, notification history, clipboard thumbs); a
flat high plateau is eager allocation at startup. Measure before fixing.

## Phase 0 — profiling methodology (do this first, no code changes)

```sh
# RSS-over-time curve (run in background, ~1 h)
while :; do printf '%s %s\n' "$(date +%T)" "$(ps -o rss= -C qs)"; sleep 30; done
```

1. **Idle curve** — fresh `qs -c rice`, record RSS every 30 s for 30–60 min
   with zero interaction. Flat plateau → startup eager-allocation problem;
   upward slope → retention problem.
2. **Feature deltas** — measure RSS before/after exercising each feature
   ~20×: open/close dashboard, clipboard panel, wallpaper picker (scroll
   through ~100 entries!), lock/unlock (testMode or a real short lock),
   tray menus, image notifications. The biggest delta names the culprit.
3. **Per-surface accounting** — `hyprctl layers` before/after each test;
   count mapped surfaces × full-screen buffer size (1920×1080×4 ≈ 8 MB per
   buffer, ×2–3 for swapchains) to see how much is window overhead vs image
   data.
4. Optional deep dive if RSS stays mysterious: `heaptrack qs -c rice`
   (package `heaptrack`) or `valgrind --tool=massif` — heavy, only after the
   cheap curves point somewhere.

## Suspects, ranked (hypotheses — verify each before fixing)

1. **Lockscreen wallpaper retained after unlock** — *verified*: no lock
   surface is mapped while unlocked, so the wallpaper does NOT decode at
   boot. (The `Component.onCompleted` load trigger in `Lockscreen.qml`
   exists because the surface is created with `wallpaperPath` already set —
   an `onWallUrlChanged`-only trigger would never fire; that is a load
   trigger, not a boot-time decode.) The open question is the opposite:
   whether the decoded wallpaper + blur FBOs are **released** when the
   surface is destroyed on unlock. *Test: RSS before engage vs right after
   unlock; if a permanent ~10–30 MB step remains (current wallpaper
   2048×1228 ≈ 10 MB decoded), null the Image source and the MultiEffect
   source on the unlock path.*
2. **Lockscreen `MultiEffect` blur chain** — full-screen blur allocates
   FBOs at surface size while the lock surface exists. Verify the chain is
   released on unlock (surface destroyed ⇒ buffers freed — confirm with the
   RSS curve across a lock/unlock cycle). If retained, null the effect
   source on unlock.
3. **Wallswitch image cache growth** — slot images use `cache: true` with
   decode width quantized to 128 px steps (good), but browsing hundreds of
   wallpapers accumulates decoded pixmaps in the Qt image cache. *Test:
   RSS before/after scrolling ~100 entries. Fix candidates: `cache: false`
   on slot images (quantization already amortizes decode cost) or a bounded
   cache.*
4. **Fullscreen shield windows** — RicePopup architecture means ~7
   full-screen layer surfaces exist (4 popups + clipboard + wallswitch +
   lock). Confirm unmapped ones hold no buffers (they should — windows are
   mapped on demand); if any buffer persists while hidden, that is worth a
   Quickshell issue, not a config workaround.
5. **Notification history images** — `imageSupported: true` and history
   snapshots are plain JS data; check whether image payloads are retained in
   the 30-entry history (they should not be — strip to a thumbnail or drop
   the payload on push).
6. **Clipboard expanded text** — already capped at 64 KB per decode; low
   priority.
7. **Engine floor** — whatever remains after the above is the Quickshell/QML
   baseline; document it as the floor rather than chasing it.

## Ground rules for the optimization pass

- Fix one suspect at a time, re-run the Phase 0 curve after each — attribute
  wins to measurements, not vibes.
- Never restart/kill `qs` while the session lock is engaged (bricks the
  session; recovery is TTY + `loginctl unlock-session`).
- The popup architecture is deliberate — do not "optimize" it away.
- Update this file as items land (strike them, keep the measured delta), and
  mirror anything load-bearing into AGENTS.md.

**Target**: idle RSS < 200 MB, no growth over a 24 h idle curve.
