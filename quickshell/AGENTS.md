# AGENTS.md — agent notes for quickshell_rice

Reference for AI agents / new sessions working on this repo. Read this before
changing anything. `README.md` covers user-facing usage,
**[developers.md](developers.md)** the human-developer guide (stable
architecture + workflows); this file is the **hub**: the hard rules, the repo
map, and the index into `docs/agents/` — one file per subsystem, moved
near-verbatim out of the old single-file AGENTS.md (903 lines / 69 KB,
split 2026-11-03 — nothing was deleted, only reorganized; fix "see below"
pointers accordingly).

## What this is

A Quickshell desktop shell for **Arch Linux + Hyprland ≥ 0.56**, built for
**Quickshell 0.3.1** (QML). Layout: workspaces (left), clock + bell (center),
tray/volume/mic/wifi/bluetooth/battery/power (right). Colors are not
hardcoded — the palette is recolored live from the wallpaper via matugen
(defaults = the original pink rice). The design and iconography mirror the
user's waybar setup — `~/.config/waybar/config.jsonc` is the reference for
Nerd Font glyph codepoints and per-state icon behavior.

Run: `qs -c rice` (named config — `~/.config/quickshell/rice` → this repo).
Quickshell hot-reloads on every file save — you do not need to restart to
test QML edits (`pgrep -x qs` / `hyprctl layers` first; see
[docs/agents/workspaces-stale-cache.md](docs/agents/workspaces-stale-cache.md)).

## Hard rules checklist

Do not break these without reading the linked doc first — each one cost a
real debugging session.

1. Popups are full-screen transparent layer-shell **shields** with the panel
   inside — never `PopupWindow`/xdg popups. Opening/closing flows through the
   `Popups` singleton (re-click toggles, outside-click closes); EVERY popup,
   incl. `TrayMenuPopup`, stays wired into it.
2. Clicks inside a panel never close it — the `RicePopup` swallower
   `MouseArea` stays declared BEFORE the content alias.
3. Never use `QsWindow.mask` (goes stale → click-through bar). Tooltips and
   toasts are small mapped-only windows with `exclusionMode: Normal` +
   `exclusiveZone: -1`, or Hyprland shifts them ~46 px down.
4. `Pipewire`/`Networking`/`UPower`/`SystemTray` are **singletons** — never
   instantiate. Volume/mute bind only with a `PwObjectTracker` present.
   `Mpris.players` and `Networking.devices` are ObjectModels — iterate via
   `.values`.
5. `NotificationServer` is created ONCE at shell root; `Notifs.push` must
   record history **before** the DND/dashboard early return; `n.tracked = true`
   is not optional; every `n.expire()/dismiss()` wrapped in try/catch.
6. Every scrollable list binds its vertical ScrollBar's policy off actual
   scroll (`<id>.contentHeight > <id>.height ? AlwaysOn : AlwaysOff`) —
   `ScrollBar.AsNeeded` maps the bar even when nothing overflows (a one-notif
   list showed a phantom full-length handle). Delegates gate the scrollbar
   lane the same way: `sbShown`-gated `width: <id>.width - (sbShown ? 14 : 4)`
   — the 14px lane exists only while the bar shows (width animates via a
   Behavior) — and Flickables still have NO `rightPadding`.
7. Anchoring data (`wifiRightX` etc. on `StatusPill`, `anchorX` on `Bar`) is
   load-bearing — a NaN anchorX opens a popup *invisibly*. Do not delete.
8. A `RicePopup` subclass `onVisibleChanged` handler shadows the base class's
   — attach via `Connections { target: root; function onVisibleChanged() … }`.
9. Singletons do nothing until first accessed (`ScreenTime.init()` is called
   from shell.qml for exactly this reason); `qmldir` lists every component
   exactly once (singleton listed twice = nothing loads).
10. Fire-and-forget Actions (awww, matugen, greetd sync) live in
    `core/Actions.qml` — never inside a lazily created/destroyed popup, or
    the Process dies with the tree before it runs.
11. Workspace pill: ONE fixed cell width; color-only animation; never
    reintroduce wider-active. Edge-ness derives from data (`root.wsValues`),
    never `Repeater.count`/id (not resolvable in Pill delegates — derives
    `ReferenceError`s forever).
12. Lockscreen: never guard `engage()` on `LockState.engaged` — the guard is
    the screen's own `sessionActive`. Killing quickshell while locked =
    locked out; recovery is TTY + `loginctl unlock-session`.
13. matugen `[config.wallpaper] set = false` with `command`/`arguments`
    present must stay; awww transitions must be valid (`fade`, `wipe`,
    `outer`, `grow`, `random`).
14. Layer-shell windows: MultiEffect `maskSource` renders nothing — use
    `RoundedImage` (Canvas clip). Opacity is `Theme.popupBg`, layer namespaces
    matter to layerrules (`quickshell:bar`, `:popup`, `:toast`, `:tooltip`,
    `quickshell:wallswitch`).
15. stale cache: map-but-paint-nothing → `rm -rf ~/.cache/quickshell
    /run/user/1000/quickshell/vfs` and relaunch before debugging anything
    else. `pgrep -x qs` / `hyprctl layers` FIRST.
16. Verify logs with `console.warn` (console.log never surfaces); PAM path
    for the lock is literally `login` (same stack hyprlock gets).
17. Hyprland ≥ 0.56 IPC is Lua (`hl.dsp.focus({ workspace = N })`). From
    scripts, shortcuts fire ONLY via
    `hyprctl dispatch 'hl.dsp.global("qs-bar:powermenu")'` — `eval` is a no-op
    for descriptors.
18. Debugging colors: never hardcode — every color binding follows
    `Colors.md3` via `Theme`. Until matugen's first run the md3 strings are
    `"transparent"` and Theme falls back to baked-in hex.
19. The user verifies interactions manually — never script mouse input; use
    `hyprshot` for screenshots (`grim -g` only for known fixed regions).
20. `qs -c rice` hot-reloads — after edits, check the log for errors before
    trusting the visual result; `hyprctl layers` shows whether it relaunched.

## Read before you change

| You're modifying… | Read first |
|---|---|
| popups/, RicePopup, TooltipWindow, toast, popups' keyboard nav, QsWindow.mask, layer namespaces | [`docs/agents/popups-layer-surfaces.md`](docs/agents/popups-layer-surfaces.md) |
| shell.qml NotificationServer, Notifs, Toast, Osd, notifications | [`docs/agents/notifications-osd.md`](docs/agents/notifications-osd.md) |
| Pipewire/Wi-Fi/BT/battery/tray/Mpris services, Hyprland dispatch syntax | [`docs/agents/services-api.md`](docs/agents/services-api.md) |
| Theme/Colors/Icons/fonts, matugen templates, palette roles | [`docs/agents/palette-icons-fonts.md`](docs/agents/palette-icons-fonts.md) |
| Workspaces.qml, bars that map but render nothing | [`docs/agents/workspaces-stale-cache.md`](docs/agents/workspaces-stale-cache.md) |
| DashPopup, SystemUsage, ScreenTime, calendar column | [`docs/agents/system-usage-screentime.md`](docs/agents/system-usage-screentime.md) |
| Lockscreen, PAM, LockState, hypridle lock flow | [`docs/agents/lockscreen.md`](docs/agents/lockscreen.md) |
| Wallswitch, wallpaper apply (awww/matugen), Actions.qml | [`docs/agents/wallswitch.md`](docs/agents/wallswitch.md) |
| Memory usage, lazy popups, autostart's MALLOC_* tuning | [`docs/agents/memory-lazy-popups.md`](docs/agents/memory-lazy-popups.md) |
| `greeter/`, greetd, `/etc/greetd/greeter/` | [`docs/agents/greeter.md`](docs/agents/greeter.md) |

## File map

2026-10-06: components are grouped by role — `core/` (singletons), `ui/`
(primitives), `bar/` (bar + Osd + Toast), `popups/` (RicePopup panels +
TrayMenuPopup), `standalone/` (Wallswitch, Lockscreen). Rows below carry their
directory; bare file names elsewhere in this doc resolve via this map. Each
directory has its own `qmldir`; cross-directory references use explicit
relative imports (`import "../core"`).

| File | Role |
|---|---|
| `shell.qml` | Entry point. `//@ pragma UseQApplication` is **required** (tray menus need it). Hosts the `GlobalShortcut`s (`powermenu` + `notification` under appid `qs-bar`, `wallpaper-switcher` under appid `qs`), the `NotificationServer` (once, NOT per-screen — see `docs/agents/notifications-osd.md`), and the `Toast`, `Osd` and `Wallswitch` windows. `Variants` spawns one `Bar` per screen (declared BEFORE `Wallswitch` so the picker's invisible input shield stacks above the bar). |
| `bar/Bar.qml` | 46px `PanelWindow` (layer Top). Anchors the three pills and instantiates the four `RicePopup`s + `TrayMenuPopup`. Also hosts `showTooltip()`/`hideTooltip()` which delegate to `TooltipWindow`. |
| `bar/Workspaces.qml` | Hyprland workspaces, min 5 persistent slots (`minCount`), click switches via dispatch. Urgent workspaces tint orange. Every cell (first/last, idle/hover/active) shares ONE fixed width — no edge caps — so the pill resizes only when the workspace count changes (see `docs/agents/workspaces-stale-cache.md`). |
| `bar/ClockPill.qml` | Center pill: stateful bell + time (no clock glyph — removed 2026-10-04). Bell mirrors waybar's notification-module glyphs via `Notifs.unread`/`Notifs.dnd`; unread also boosts color from fgMuted to fg. Owns a `SystemClock`. Hover = date tooltip, click = dashboard popup. |
| `bar/StatusPill.qml` | Right pill: SystemTray items, volume (scroll ±1% / click mute), mic, wifi, bluetooth, battery, power. Exposes `wifiRightX`/`btRightX`/`powerRightX` so Bar can anchor popups under the right icons — **do not delete these**, the popups depend on them. |
| `core/Popups.qml` (singleton) | `active` = name of the open popup ("" / "clock" / "wifi" / "bt" / "power" / "tray" / "wall"). Single source of truth for popup exclusivity. `lastDismiss` guards against the outside-click that dismissed a popup re-triggering a toggle. |
| `popups/RicePopup.qml` | Base class for dash/wifi/bt/power popups: full-screen transparent layer-shell "shield", visible rounded panel anchored inside it, closes on outside click / `Esc` / `Popups.active` change. `panelWidth` + optional `panelHeight` (0 = auto-size from content); panel x is clamped to the screen. |
| `standalone/Lockscreen.qml` | Session lock (hyprlock replacement): blurred awww wallpaper, 12h clock + date, PAM password dots, battery + weather + status (right column), MPRIS media card, keyboard-layout switcher. Lives in the main shell instance; engages via `LockState` / `qs:lock` shortcut. See `docs/agents/lockscreen.md`. |
| `core/LockState.qml` (singleton) | `engaged` bool bridging lock triggers (PowerPopup's Lock action, future callers) to `Lockscreen.engage()`. Never set `engaged = false` to bypass auth — that's what TTY `loginctl unlock-session` is for. |
| `popups/WifiPopup.qml` | Wi-Fi toggle, networks sorted by signal (connected first), max 5 visible + scroll, inline password prompt (`connectWithPsk`). |
| `popups/BluetoothPopup.qml` | Adapter toggle, devices (paired first), pair/connect/disconnect on click. |
| `popups/PowerPopup.qml` | Power Off / Reboot / Suspend / Log Out / Hibernate / Lock (6 rows, 5 visible + scroll). Commands + letter keybinds mirror `~/.config/wlogout/layout`; grabs exclusive keyboard while open (`grabKeys`). |
| `popups/DashPopup.qml` | Clock-click dashboard (replaces the old `CalendarPopup`): calendar column (left, 310px) + hairline divider + notifications column (right), fixed `panelHeight` 540 so a playing media card only takes space from the list. `popupName: "clock"`, anchored centered on the clock pill. Below the calendar sits the system-usage section (profile rows + CPU/mem/disk bars) — start()/stop() on open/close. |
| `popups/CalendarPanel.qml` | Month grid + weekday/date header, extracted verbatim from the old `CalendarPopup`; `resetMonth()` called by DashPopup on every open. Exposes `contentHeight` (actual month) and `maxContentHeight` (6-row worst case) — DashPopup sizes the panel to the former and reserves the latter, so the system-usage section below sits at a fixed y in every month. |
| `popups/SystemUsage.qml` | Profile/system section at the bottom of the dashboard's calendar column: fastfetch-style rows (distro from /etc/os-release, screen time, verbose uptime) next to the circular avatar (assets/pfp.png), then CPU (+ temp) / Memory / total-Disk bar rows. NO card background — blended into the popup. Quickshell 0.3.1 has no system-info service — everything is polled from `/proc` + `/sys` + `df` with FileView+Timer (see `docs/agents/system-usage-screentime.md`). |
| `ui/RoundedImage.qml` | Rounded-corner image (avatar, lock-screen photo + album art). Originally a MultiEffect mask with an offscreen white item — that NEVER renders in layer-shell windows (see `docs/agents/system-usage-screentime.md`); rewritten as a Canvas-drawn clip. Same API: `source`, `imgStatus`, `rounding`. |
| `core/ScreenTime.qml` (singleton) | Cumulative "screen time today" accumulator (Android-style, resets at midnight). `IdleMonitor` (ext-idle-notify, 330s, inhibitors respected) mirrors the user's hypridle DPMS-off listener; persists to `~/.cache/quickshell_rice/screen-time` (`<yyyy-MM-dd> <seconds>` sidecar). Must run all day even when the dashboard is never opened → singleton, `init()` called from shell.qml `Component.onCompleted` (singletons are lazy — without that first touch NOTHING runs). |
| `popups/NotifsPanel.qml` | Right column of the dashboard: MPRIS player card(s) docked on top (`Mpris.players` filtered to non-stopped), notification history ListView, bell "No Notifications" empty state, footer with DND `Toggle` + `Clear`. History is a **ListModel mirrored from `Notifs.history`** (`syncHistory()`, keyed by the entry's stable `entryId`) — a plain-array model would reset the ListView on every change, wiping per-row expanded state and blocking per-item animations. Rows: click = expand/collapse the full wrapped body (row height is `Math.max(48, contentCol.implicitHeight + 14)` in both states — content-sized with a 48px floor for title-only rows, so a click can only ever GROW a row; the title un-truncates and wraps together with the body, nothing shows "…" when expanded; grows DOWNWARD only — content is top-anchored; center-anchored made the row grow both ways, the "bouncy" effect); expanded state is a model role (`setProperty`), so removing one row keeps others expanded; ✕ removes with a swipe-out (`ListView.onRemove` + `delayRemove`); new rows slide in from the right; `Clear` swipes every row out IN PLACE (per-row `leaving` role, staggered top-down, no vertical reflow) and drops the model in one pass. |
| `core/Notifs.qml` (singleton) | Notification history (plain JS snapshots, capped 30, newest first), `dnd`, current `toast` entry, `push/remove/clearAll/closeToast`. `push` sets `n.tracked = true` — see `docs/agents/notifications-osd.md`. |
| `bar/Toast.qml` | Top-right toast banner (small mapped-only window, TooltipWindow pattern). Timer mirrors the user's old swaync timings: 2s low / 4s normal / 6s critical; app-supplied `expireTimeout` (ms) wins when > 0, clamped 2–15s. Hidden while DND or the dashboard is open. Click = expand/collapse the full body (timer PAUSES while expanded so it can't vanish mid-read); the summary line un-truncates and wraps when expanded, matching NotifsPanel (row is content-sized, so expansion only grows); a small always-visible ✕ in the corner dismisses. Content is top-anchored so expansion grows downward. |
| `bar/Osd.qml` | Volume / mic / brightness OSD — service-driven (Pipewire + backlight poll), Overlay layer; NOT notification-driven (see `docs/agents/notifications-osd.md`). |
| `standalone/Wallswitch.qml` | Slanted wallpaper picker (skwd-wall "Slices" look, right-leaning) floating over the live desktop — NO dim backdrop, invisible input shield. 9-slot recycled carousel (4 strips per side), type-to-search, preview-first UX; applies via the `awww` + `matugen` binaries directly — the rofi `wall-switcher.sh` is retired (see `docs/agents/wallswitch.md`). |
| `shaders/` | Prebuilt `.qsb` shaders for Wallswitch's slot rendering (AA'd parallelogram mask). Sources kept alongside; recompile command in `docs/agents/wallswitch.md`. |
| `popups/TrayMenuPopup.qml` | Themed DBusMenu renderer for tray items (`QsMenuOpener`), one submenu drill-down level with a Back row. Scroll position resets on every open. |
| `ui/TooltipWindow.qml` | Small floating window rendering ONE hover tooltip; positioned via layer-shell margins. Only mapped while showing. |
| `ui/NIcon.qml` | Fixed-square `Text` rendering one Nerd Font glyph from `Icons`. |
| `core/Icons.qml` (singleton) | Glyph codepoint map + `batteryGlyph(level, charging)` + per-glyph `yOffset()` vertical corrections. |
| `core/Theme.qml` (singleton) | Fonts (`fontFamily` = Rubik for all text, `nerdFont` = JetBrains Mono Nerd Font Propo for glyphs), the single `textSize` token (14.5 — every non-icon Text uses it, nothing bold), metrics, and the palette: color properties with pink-rice defaults that matugen overlays from `Colors.md3` (see `docs/agents/palette-icons-fonts.md`). |
| `ui/Pill.qml` | Base rounded pill; declared children go into an inner Row. `rowX` exposed for popup anchoring. |
| `ui/SignalBars.qml`, `ui/Toggle.qml` | Wifi signal bars, on/off switch (pure QML, no Controls styling). |
| `qmldir` (one per directory) | **Every** component must be listed here (singletons + types) — see Hard rules above. |

## Extra notes / user preferences

- **Verification is manual.** The user verifies interactions themselves — do
  not script mouse input (ydotool is installed but off-limits unless asked),
  and never parse their mouse coordinates from screenshots.
- **Screenshots: `hyprshot`, not grim** (e.g. `hyprshot -m output -m eDP-1
  --raw > out.png`; it exits 1 even on success). Exception verified working:
  `grim -g "X,Y WxH" out.png` for fixed-region grabs of known coordinates
  (top-left bar area) — exits 0 and is what the workspaces pixel-scan checks
  used.
- The user's Hyprland config is **Lua**; keep any generated dispatch strings
  valid Lua.
- **wlogout replacement workflow**: `shell.qml` registers `GlobalShortcut`
  (appid "qs-bar", name "powermenu") and `PowerPopup` grabs exclusive keyboard
  focus while open — `Keys.onPressed` maps s/r/u/l/h/e to the actions. The
  user binds it in their Lua config with
  `hl.bind("ALT + X", hl.dsp.global("qs-bar:powermenu"))` (verified end-to-end
  against Hyprland 0.56) and is removing wlogout; commands/keybinds stay in
  sync with `~/.config/wlogout/layout` (kept only as reference). `IpcHandler`
  does NOT exist in Quickshell 0.3.1 — GlobalShortcut is the only bind entry
  point. Same pattern for the dashboard: `hl.dsp.global("qs-bar:notification")`
  (the user binds mainMod+N themselves; mainMod = ALT in their config; the
  shortcut only toggles — no keyboard grab).
  Note `hyprctl dispatch global ...` cannot trigger these from a script —
  it dies in the Lua parser.
- Live data looks "wrong" sometimes because it *is* live: volume 0% + muted
  icon means the sink actually is, battery follows the real battery (it drains
  between screenshots), bluetooth icon flips with adapter state.
- Debugging loop that works: `qs -p <file-or-dir>` in background, read stderr /
  `/run/user/1000/quickshell/<id>/log.qslog`, screenshot with hyprshot + crop
  with `magick`. Non-visual singletons/components can be probed with a throwaway
  QML file run the same way (keep test files out of this repo). **Kill throwaway
  instances when done** — a stray `qs -p shell.qml` from an old session survived
  a day and pixel-overlapped the real `qs -c rice` bar invisibly.
- Popup layout can be verified without clicking the bar: run a second
  throwaway `qs` instance from /tmp that imports the repo via
  `import "file:/home/bandit/Dev/hyprland-lq/quickshell/core"` +
  `import "file:/home/bandit/Dev/hyprland-lq/quickshell/popups"` (bare absolute
  paths are rejected — the file: URL is mandatory), flips
  `Popups.active = "<name>"` in `Component.onCompleted` (optionally seeding
  singleton state like `Notifs.history` first), then grim-crops the panel
  region. (The qmlscanner may WARN "unresolvable import" for the file: URLs —
  the QML engine resolves them fine; verified 2026-10-06. For Wallswitch or
  Lockscreen tests also import the `standalone` dir.) Two instances coexist
  fine as long as the throwaway has no
  `NotificationServer`.
- If a newer Quickshell lands in Arch `extra` (>0.3.1), re-verify this config
  before assuming it still works — deprecation warnings are the first sign.
