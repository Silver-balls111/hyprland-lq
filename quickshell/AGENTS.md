# AGENTS.md — agent notes for quickshell_rice

Reference for AI agents / new sessions working on this repo. Read this before
changing anything — most of it is the residue of real debugging sessions.
`README.md` covers user-facing usage, **[developers.md](developers.md)** is the
human-developer guide (stable architecture + workflows); this file is the
debugging-history companion, covering architecture, quirks and
conventions.

## What this is

A Quickshell desktop shell for **Arch Linux + Hyprland ≥ 0.56**, built for
**Quickshell 0.3.1** (QML). Layout: workspaces (left), clock + bell (center),
tray/volume/mic/wifi/bluetooth/battery/power (right). Colors are not
hardcoded — the palette is recolored live from the wallpaper via matugen
(defaults = the original pink rice). The design and iconography mirror the
user's waybar setup — `~/.config/waybar/config.jsonc` is the reference for
Nerd Font glyph codepoints and per-state icon behavior.

Run: `qs -c rice` (named config — `~/.config/quickshell/rice` → this repo) or
`qs -p ~/Documents/Dev/quickshell_rice/shell.qml` (Quickshell hot-reloads
the config on every file save — you do not need to restart to test QML edits).

## File map

2026-10-06: components are grouped by role — `core/` (singletons), `ui/`
(primitives), `bar/` (bar + Osd + Toast), `popups/` (RicePopup panels +
TrayMenuPopup), `standalone/` (Wallswitch, Lockscreen). Rows below carry their
directory; bare file names elsewhere in this doc resolve via this map. Each
directory has its own `qmldir`; cross-directory references use explicit
relative imports (`import "../core"`).

| File | Role |
|---|---|
| `shell.qml` | Entry point. `//@ pragma UseQApplication` is **required** (tray menus need it). Hosts the `GlobalShortcut`s (`powermenu` + `notification` under appid `qs-bar`, `wallpaper-switcher` under appid `qs`), the `NotificationServer` (once, NOT per-screen — see notification gotcha), the palette `FileView` (repo-local `colors.css`) and the `Toast`, `Osd` and `Wallswitch` windows. `Variants` spawns one `Bar` per screen (declared BEFORE `Wallswitch` so the picker's invisible input shield stacks above the bar). |
| `bar/Bar.qml` | 46px `PanelWindow` (layer Top). Anchors the three pills and instantiates the four `RicePopup`s + `TrayMenuPopup`. Also hosts `showTooltip()`/`hideTooltip()` which delegate to `TooltipWindow`. |
| `bar/Workspaces.qml` | Hyprland workspaces, min 5 persistent slots (`minCount`), click switches via dispatch. Urgent workspaces tint orange. Every cell (first/last, idle/hover/active) shares ONE fixed width — no edge caps — so the pill resizes only when the workspace count changes (see Workspaces gotcha). |
| `bar/ClockPill.qml` | Center pill: stateful bell + time (no clock glyph — removed 2026-10-04). Bell mirrors waybar's notification-module glyphs via `Notifs.unread`/`Notifs.dnd`; unread also boosts color from fgMuted to fg. Owns a `SystemClock`. Hover = date tooltip, click = dashboard popup. |
| `bar/StatusPill.qml` | Right pill: SystemTray items, volume (scroll ±1% / click mute), mic, wifi, bluetooth, battery, power. Exposes `wifiRightX`/`btRightX`/`powerRightX` so Bar can anchor popups under the right icons — **do not delete these**, the popups depend on them. |
| `core/Popups.qml` (singleton) | `active` = name of the open popup ("" / "clock" / "wifi" / "bt" / "power" / "tray" / "wall"). Single source of truth for popup exclusivity. `lastDismiss` guards against the outside-click that dismissed a popup re-triggering a toggle. |
| `popups/RicePopup.qml` | Base class for dash/wifi/bt/power popups: full-screen transparent layer-shell "shield", visible rounded panel anchored inside it, closes on outside click / `Esc` / `Popups.active` change. `panelWidth` + optional `panelHeight` (0 = auto-size from content); panel x is clamped to the screen. |
| `standalone/Lockscreen.qml` | Session lock (hyprlock replacement): blurred awww wallpaper, 12h clock + date, PAM password dots, battery + weather + status (right column), MPRIS media card, keyboard-layout switcher. Lives in the main shell instance; engages via `LockState` / `qs:lock` shortcut. See its section below. |
| `core/LockState.qml` (singleton) | `engaged` bool bridging lock triggers (PowerPopup's Lock action, future callers) to `Lockscreen.engage()`. Never set `engaged = false` to bypass auth — that's what TTY `loginctl unlock-session` is for. |
| `popups/WifiPopup.qml` | Wi-Fi toggle, networks sorted by signal (connected first), max 5 visible + scroll, inline password prompt (`connectWithPsk`). |
| `popups/BluetoothPopup.qml` | Adapter toggle, devices (paired first), pair/connect/disconnect on click. |
| `popups/PowerPopup.qml` | Power Off / Reboot / Suspend / Log Out / Hibernate / Lock (6 rows, 5 visible + scroll). Commands + letter keybinds mirror `~/.config/wlogout/layout`; grabs exclusive keyboard while open (`grabKeys`). |
| `popups/DashPopup.qml` | Clock-click dashboard (replaces the old `CalendarPopup`): calendar column (left, 310px) + hairline divider + notifications column (right), fixed `panelHeight` 540 so a playing media card only takes space from the list. `popupName: "clock"`, anchored centered on the clock pill. Below the calendar sits the system-usage section (profile rows + CPU/mem/disk bars) — start()/stop() on open/close. |
| `popups/CalendarPanel.qml` | Month grid + weekday/date header, extracted verbatim from the old `CalendarPopup`; `resetMonth()` called by DashPopup on every open. Exposes `contentHeight` (actual month) and `maxContentHeight` (6-row worst case) — DashPopup sizes the panel to the former and reserves the latter, so the system-usage section below sits at a fixed y in every month. |
| `popups/SystemUsage.qml` | Profile/system section at the bottom of the dashboard's calendar column: fastfetch-style rows (distro from /etc/os-release, screen time, verbose uptime) next to the circular avatar (assets/pfp.png), then CPU (+ temp) / Memory / total-Disk bar rows. NO card background — blended into the popup. Quickshell 0.3.1 has no system-info service — everything is polled from `/proc` + `/sys` + `df` with FileView+Timer (see its section below). |
| `ui/RoundedImage.qml` | Rounded-corner image (avatar, lock-screen photo + album art). Originally a MultiEffect mask with an offscreen white item — that NEVER renders in layer-shell windows (see the system-usage section below); rewritten as a Canvas-drawn clip. Same API: `source`, `imgStatus`, `rounding`. |
| `core/ScreenTime.qml` (singleton) | Cumulative "screen time today" accumulator (Android-style, resets at midnight). `IdleMonitor` (ext-idle-notify, 330s, inhibitors respected) mirrors the user's hypridle DPMS-off listener; persists to `~/.cache/quickshell_rice/screen-time` (`<yyyy-MM-dd> <seconds>` sidecar). Must run all day even when the dashboard is never opened → singleton, `init()` called from shell.qml `Component.onCompleted` (singletons are lazy — without that first touch NOTHING runs). |
| `popups/NotifsPanel.qml` | Right column of the dashboard: MPRIS player card(s) docked on top (`Mpris.players` filtered to non-stopped), notification history ListView, bell "No Notifications" empty state, footer with DND `Toggle` + `Clear`. History is a **ListModel mirrored from `Notifs.history`** (`syncHistory()`, keyed by the entry's stable `entryId`) — a plain-array model would reset the ListView on every change, wiping per-row expanded state and blocking per-item animations. Rows: click = expand/collapse the full wrapped body (grows DOWNWARD only — content is top-anchored; center-anchored made the row grow both ways, the "bouncy" effect); expanded state is a model role (`setProperty`), so removing one row keeps others expanded; ✕ removes with a swipe-out (`ListView.onRemove` + `delayRemove`); new rows slide in from the right; `Clear` resets instantly (no swipe storm). |
| `core/Notifs.qml` (singleton) | Notification history (plain JS snapshots, capped 30, newest first), `dnd`, current `toast` entry, `push/remove/clearAll/closeToast`. `push` sets `n.tracked = true` — see notification gotcha. |
| `bar/Toast.qml` | Top-right toast banner (small mapped-only window, TooltipWindow pattern). Timer mirrors the user's old swaync timings: 2s low / 4s normal / 6s critical; app-supplied `expireTimeout` (ms) wins when > 0, clamped 2–15s. Hidden while DND or the dashboard is open. Click = expand/collapse the full body (timer PAUSES while expanded so it can't vanish mid-read); a small always-visible ✕ in the corner dismisses. Content is top-anchored so expansion grows downward. |
| `bar/Osd.qml` | Volume / mic / brightness OSD — service-driven (Pipewire + backlight poll), Overlay layer; NOT notification-driven (see its gotcha section). |
| `standalone/Wallswitch.qml` | Slanted wallpaper picker (skwd-wall "Slices" look, right-leaning) floating over the live desktop — NO dim backdrop, invisible input shield. 9-slot recycled carousel (4 strips per side), type-to-search, preview-first UX; applies via the `awww` + `matugen` binaries directly — the rofi `wall-switcher.sh` is retired (see its section below). |
| `shaders/` | Prebuilt `.qsb` shaders for Wallswitch's slot rendering (AA'd parallelogram mask). Sources kept alongside; recompile command in the wallpaper section. |
| `popups/TrayMenuPopup.qml` | Themed DBusMenu renderer for tray items (`QsMenuOpener`), one submenu drill-down level with a Back row. Scroll position resets on every open. |
| `ui/TooltipWindow.qml` | Small floating window rendering ONE hover tooltip; positioned via layer-shell margins. Only mapped while showing. |
| `ui/NIcon.qml` | Fixed-square `Text` rendering one Nerd Font glyph from `Icons`. |
| `core/Icons.qml` (singleton) | Glyph codepoint map + `batteryGlyph(level, charging)` + per-glyph `yOffset()` vertical corrections. |
| `core/Theme.qml` (singleton) | Fonts (`fontFamily` = Rubik for all text, `nerdFont` = JetBrains Mono Nerd Font Propo for glyphs), the single `textSize` token (14.5 — every non-icon Text uses it, nothing bold), metrics, and the palette: color properties with pink-rice defaults that `applyPaletteCss()` overlays from matugen (see palette gotcha). |
| `ui/Pill.qml` | Base rounded pill; declared children go into an inner Row. `rowX` exposed for popup anchoring. |
| `ui/SignalBars.qml`, `ui/Toggle.qml` | Wifi signal bars, on/off switch (pure QML, no Controls styling). |
| `qmldir` (one per directory) | **Every** component must be listed here (singletons + types) — see gotchas. |

## Critical gotchas (each cost a debugging round — do not rediscover)

### Hyprland ≥ 0.56 IPC is Lua
The old `dispatch workspace N` syntax is a Lua parse error now (even
`hyprctl dispatch` fails). Working form: `hl.dsp.focus({ workspace = N })`.
`Workspaces.qml` probes `hyprctl version` at startup and falls back to the old
syntax on Hyprland < 0.56. Enumerating Lua APIs: the socket evaluates `eval`
requests, and `WifiSecurityType.toString(i)`-style calls reveal enum names.

### Popup architecture is deliberate — don't "simplify" it
- `PopupWindow`/xdg popups from a layer-shell bar are broken (grab failures,
  clicks swallowed). Popups are therefore **full-screen transparent layer-shell
  shield windows** with the visible panel positioned inside at
  `y: Theme.barHeight` — a re-click on the bar lands inside the shield at valid
  coordinates and closes the popup.
- All popups share the `Popups` singleton: opening one closes the others;
  re-clicking the same trigger closes it. Keep `TrayMenuPopup` wired in too.
- Clicks INSIDE the panel never close it: `body` in `RicePopup` holds a plain
  full-size MouseArea (the "swallower") declared before the content alias, so
  background/spacing/disabled-control clicks are consumed instead of falling
  through to the shield. Before it existed, clicking a disabled media button
  or any empty area closed the popup (the user caught this). Subclass content
  lands above the swallower, so real controls still get their clicks.
- **Every scrollable list keeps its delegates ~14px narrower than the
  ListView** (`width: <list>.width - 14`) so the attached ScrollBar lives in
  its own lane and never overlays right-edge content (Wi-Fi lock/check
  icons, power-menu keybind hints, tray-menu submenu arrows, notification
  hover-✕). Applies to WifiPopup, BluetoothPopup,
  PowerPopup, TrayMenuPopup and NotifsPanel — ANY new
  scrolling list does the same from day one (ListView/Flickable have no
  padding properties to lean on).
- Anchoring data (`wifiRightX` etc. on StatusPill, `anchorX` on Bar) is easy to
  drop during rewrites — a NaN anchorX makes a popup open *invisibly*.
- Hover-out auto-close was removed on purpose: it fired when the shield mapped
  under the cursor and stole the pill's hover. Calendar = click-open, closes on
  re-click / outside click / `Esc` only.

### Never use `QsWindow.mask` (Quickshell 0.3.1)
Region/mask geometry goes stale ("updates aren't automatic" per docs) and an
empty/stale mask makes the whole bar click-through. The bar window is a plain
46px strip with no mask for this reason. Tooltips use a **small** window
instead of a full-screen overlay with an "empty" mask — 0.3.1 may ignore such
masks, and a full-screen tooltip overlay then eats every click.

### Tooltip + toast positioning
The tooltip window is top+left anchored and positioned via `margins`. It must
set `exclusionMode: Normal; exclusiveZone: -1`, otherwise Hyprland shifts it
below the bar's 46px exclusive zone (~46px too low). `Toast.qml` needs the
same two lines (forgot them initially — the banner rendered ~46px too low).
Vertical gap convention: pill bottom + 6px; all status tooltips pass the whole
pill as the `yItem` so every tooltip sits at one height. Toast sits at
`barHeight + 8` on the right.

### Services API quirks (verified on 0.3.1)
- `Pipewire`, `Networking`, `UPower`, `SystemTray` are **singletons** — never
  instantiate them.
- Pipewire volume/mute live at `Pipewire.defaultAudioSink.audio.volume/muted`
  and only bind with a `PwObjectTracker { objects: [...] }` present.
- UPower populates ~3s after launch: gate on `displayDevice.ready`, and
  `percentage` is 0–1 (multiply by 100). `timeToEmpty`/`timeToFull` are seconds.
- Module paths: Bluetooth is `Quickshell.Bluetooth` (not `Services.`); tray
  methods are `activate()`, `secondaryActivate()`, `scroll(delta, horizontal)`,
  `display(win, x, y)`; menus come from the `menu` handle.
- Enums read as `TypeName.Value` (`DeviceType.Wifi`, `ConnectionState.Connected`
  = 2, `UPowerDeviceState.Charging` = 1, `BluetoothDeviceState.Connected` = 1,
  `WifiSecurityType.Open` = 10). qmltypes files are incomplete/empty (Hyprland,
  Widgets) — types still exist at runtime.
- `Mpris` / `MprisPlayer` (`Quickshell.Services.Mpris`, qmltypes complete):
  `Mpris.players` is an ObjectModel — iterate via `Mpris.players.values` (same
  as `Networking.devices.values`). `playbackState` is
  `MprisPlaybackState.Stopped/Playing/Paused`; `trackArtists` is a single
  QString (NOT a list, despite the name — same backing as `trackArtist`);
  `trackArtUrl` is a plain URL usable directly in an `Image`; transport
  methods `togglePlaying()/next()/previous()` guarded by
  `canTogglePlaying/canGoNext/canGoPrevious`.
- `NotificationServer` / `Notification` (`Quickshell.Services.Notifications`,
  qmltypes complete): server is instantiable (NOT a singleton), has NO
  do-not-disturb property (DND is our own state in `Notifs`). `Notification`
  has `tracked` (writable — MUST be set true, see gotcha), `expireTimeout`
  (ms), `urgency` (Low/Normal/Critical), methods `expire()`/`dismiss()`.
- QML files in this dir require a `qmldir` entry each; singleton + component
  listing the same file twice fails to load; QML property names cannot start
  with an uppercase letter.

### Quickshell owns notifications now — swaync is gone (2026-10-04)
- The `NotificationServer` in `shell.qml` claims `org.freedesktop.Notifications`.
  If swaync (or any other daemon) is running, only one of them wins the DBus
  name — kill swaync before testing (`killall swaync`; it was autostarted from
  `~/.config/hypr/config/autostart.lua`, which the user removes themselves).
- **If notifications ever disappear mysteriously, suspect name theft.** This
  happened once (2026-10-04): the user had a GNOME session open for reference,
  and its standalone notification daemon (a dbus-activatable `gjs` process
  running `/usr/share/gnome-shell/org.gnome.Shell.Notifications`) grabbed
  `org.freedesktop.Notifications` the moment it was free. Symptom: no toasts,
  and the qs log only says "Could not register notification server ... already
  registered". Diagnosis: `busctl --user list | grep Notifications` — see who
  owns the name (another session's daemon, swaync, dunst, mako, ...). Close
  the other daemon/session and quickshell re-registers automatically — no bar
  restart needed. A cheap guard is still in place:
  `~/.config/dbus-1/services/org.gnome.Shell.Notifications.service` with
  `Exec=/bin/false` shadows the dbus activation for this user (harmless
  outside GNOME sessions; delete if unwanted).
- **`n.tracked = true` in `onNotification` is not optional.** Without it the
  Notification wrapper is destroyed as soon as the handler returns, and any
  later `n.expire()`/`n.dismiss()` (toast timer, click-dismiss) throws
  `TypeError: ... is not a function` — the toast still *looks* fine, so only
  the qs log reveals it. History is safe regardless because `Notifs.push`
  snapshots plain JS data, never the QObject.
- **OSD (Osd.qml, 2026-10-04)** — volume/mic/brightness indicator, a port of
  end-4's ii `OsdValueIndicator`: service-driven, NOT notification-driven.
  Volume/mic via `Connections` on `Pipewire.defaultAudioSink/Source.audio`
  (`volumeChanged`/`mutedChanged`), brightness via a 400ms `Timer` polling a
  `FileView` on `/sys/class/backlight/<dev>/brightness` (kernfs emits no
  inotify events; device discovered once via `Process ls`; first successful
  read only calibrates `lastSeenBrightness` — it must not trigger). One
  visibility flag + "current indicator"; 1000ms hide timer restarted per
  trigger; `WlrLayer.Overlay` so it shows above the dashboard's Top-layer
  shield; `armed` flag ignores the Pipewire tracker's initial attach events.
  Sync-hint notifications (`x-canonical-private-synchronous`) are dropped
  entirely in `Notifs.push` — the OSD replaces them (a dbus-send test must
  send the hint as a proper typed dict entry; dbus-send's dict parsing mangles
  keys — use the python dbus module for tests). `Notifs.osdShowing` makes the
  toast shift down below the OSD.
  - Brightness poll is adaptive: 60ms for ~1.5s after any detected change
    (burst, feels instant during key holds), 400ms baseline.
  - Volume is hard-capped at 1.0: `onVolumeChanged` writes the sink back down
    if anything sets it higher; `StatusPill` scroll also caps at 1.0.
  - OSD volume icon thresholds mirror StatusPill exactly (`muted` /
    `< 0.5 → volumeLow` / else `volumeHigh`) — keep them in sync.
- **`Notifs.push` must record history/unread BEFORE the DND / dashboard-open
  early return** — that return only suppresses the toast. Recording after it
  (a real bug for a day) made every DND'd notification vanish: the unread
  counter ticked and the bell changed, but the panel stayed empty forever.
- The server lives at shell root, not inside `Variants`: one DBus owner, and
  one `Toast`, regardless of screen count.
- `Notifs.push` drops the toast (expires immediately) when DND is on or the
  dashboard is open — the entry still lands in history (unread counts up).
  Opening the dashboard calls `Notifs.markRead()`.
- The clock pill's bell is stateful (waybar notification-module glyph set):
  none F009C / unread F116B / dnd+unread F00A0 / dnd+quiet F0A93.
- Note: `notify-send` works fine in the user's own session (verified by the
  user; their volume/brightness keybind scripts reach the bar end-to-end). An
  earlier "undefined symbol notify_notification_get_activation_app_launch_context"
  failure happened ONLY inside the agent's exec shell — its library environment
  differs from the user's session, so don't conclude "tool X is broken
  system-wide" from agent-shell failures. To send test notifications from the
  agent shell, use `dbus-send` against org.freedesktop.Notifications instead
  (or the python dbus module, which is installed).
- **`hyprctl reload` re-runs `autostart.lua`** — every `hl.exec_cmd` fires
  again. While swaync is still in that file, a mere config reload respawns it
  and it steals `org.freedesktop.Notifications` back; kill it and quickshell
  re-registers on its own.

### Keyboard navigation in popups (2026-10-04)
- `RicePopup.keyNavEnabled: true` (wifi/bt) or `grabKeys: true` (power) grabs
  exclusive keyboard while the popup is open; the base calls
  `body.forceActiveFocus()` on open. TrayMenuPopup is a standalone PanelWindow
  and sets Exclusive + its own body `Keys` itself.
- Convention per popup: a `selIndex` property + `onKeyPressed` routing —
  `Tab`/`Down` next, `Backtab`/`Up` prev (wrapping), `Home`/`End` ends,
  `Enter`/`Space` activates, and the lists scroll via
  `positionViewAtIndex(selIndex, Contain)`. Tray menu selection skips
  separators and disabled entries; `Backspace`/`Left` pops the submenu stack.
- **QML trap: a subclass `onVisibleChanged` handler SHADOWS the base class's
  handler** (one handler slot per signal in an inheritance chain) — the wifi/
  bt/power popups must attach via `Connections { target: root; function
  onVisibleChanged() {...} }` or they silently break RicePopup's
  close-bookkeeping and focus handling.
- `QsMenuOpener.children` is an ObjectModel — index it via `.values`, never
  directly.
- The dashboard popup intentionally has no keyboard nav (still OnDemand focus).

### Layer surfaces: namespaces, opacity, error banners (2026-10-04)
- Layer namespaces: `quickshell:bar` / `quickshell:popup` / `quickshell:toast` /
  `quickshell:tooltip` (renamed away from "rice-*"; the user's
  `window-rules.lua` blur rule matches `quickshell:bar`). The named qs config
  is `~/.config/quickshell/rice` → `qs -c rice`.
- **`decoration active/inactive_opacity` does NOT apply to layer surfaces** —
  no layerrule needed for opacity, and `hl.layer_rule` has NO `opacity` field
  anyway ("unknown field 'opacity'" config error). Popup/toast/tooltip opacity
  comes purely from `Theme.popupBg` (alpha 1.0 since 2026-10-04); verified by
  pixel: toast background == palette `secondary` exactly, over a dark window.
- **A Hyprland config error displaces the bar**: config-error banners have an
  exclusive zone, so `hyprctl layers` showing the bar at y≠0 means "check your
  hyprland config for errors", not "check the bar". Fixing the config and
  reloading moves it back to y=0.
- Pills are a uniform fixed `Theme.pillHeight` (36) set in `Pill.qml` itself
  (clock/status pills previously content-sized and drifted apart from the
  workspaces pill), centered via 5px top margins in the 46px bar.

### Palette is Colors.md3 (matugen quickshell.json flow) + fonts are uniform (2026-10-07)
- Flow: matugen `[templates.quickshell]` (~/.config/matugen/config.toml)
  renders `~/.config/matugen/templates/quickshell.json` →
  `~/.local/state/quickshell/generated/colors.json` (md3 = 50 roles,
  palette = 108 tonal keys, base16 = 16). `core/Colors.qml` — the InioX
  matugen-themes quickshell pattern: `Singleton` + `FileView` + `JsonAdapter`
  (watchChanges → live reload) — exposes `Colors.md3/.palette/.base16`.
  `core/Theme.qml` maps md3 roles onto the UI palette; every color binding in
  the tree follows. The old colors.css → `applyPaletteCss` flow is REMOVED
  (shell.qml's FileView and Theme's function are gone; colors.css is deleted
  from the repo).
- Role mapping (Theme.qml top): `secondary` → pillBg/popupBg (translucent),
  `secondary_fixed` → pillHover/accent/accentSoft, `on_secondary` → fg,
  `error` → urgent, `error_container` → danger (dark tone, readable on light
  pills). Derived tones (fgMuted, track, divider, border, rowHover, inputBg)
  stay formulaic on top — don't give them matugen roles. Change the mapping by
  editing those bindings, not the consumers.
- **Until matugen's first run the md3 strings are `"transparent"`** — Theme
  falls back to a snapshot hex per role (secondary #c1c6dd, secondary_fixed
  #dde2f9, on_secondary #2a3042, error #ffb4ab, error_container #93000a) so
  the shell renders normally. `"transparent"` is also what an unloadable
  colors.json yields — same fallback covers it.
- **FileView traps still apply to Colors.qml**: its `onFileChanged: reload()`
  is REQUIRED (watchChanges alone only fires the signal); a JsonAdapter
  string property is compared as a plain string (`!== "transparent"`) and
  auto-converts when assigned to a `color` property; never declare two
  handlers for the same signal (QML: "Property value set multiple times" →
  whole config fails while the old engine runs).
- matugen notes: `[config.wallpaper]` must keep `set = false` with its
  `command`/`arguments` fields present (4.2 aborts on "missing field"
  otherwise). The kitty template block is ACTIVE again (post_hook =
  `kitty +kitten themes --reload-in=all Matugen` — no more kill-SIGUSR1
  noise). The user is developing zen-browser templates: matugen can die with
  "Failed to get the input and output paths from hashmap" from THOSE —
  unrelated to quickshell (its template is #2 and regenerates before any zen
  failure; verified per-template).
- All non-icon text: `Theme.textSize` (14.5) in Rubik, **no font.weight
  anywhere** (single rule, mirrors the waybar CSS). Only NIcon sizes differ.
  Icon glyphs remain the nerd font via `Theme.nerdFont`.

### Icons are Nerd Font glyphs, not fonts-of-opportunity
All codepoints in `Icons.qml` were taken verbatim from the user's waybar config
(battery level/charging arrays, volume low/high/muted, mic, wifi, bluetooth,
bell quartet). Power intentionally uses the md power glyph (font-metric
alignment), not the ⏻ text char. The bell set (`bell`/`bellRing`/`bellDnd`/
`bellSleep`) comes from the `custom/notification` module's format-icons:
none F009C / unread F116B / dnd+unread F00A0 / dnd+quiet F0A93. Media transport
glyphs are NOT in the waybar config: play f04b, pause f04c, prev f049 (◀◀),
next f04e (▶▶), music f001, xmark f00d.
`Icons.yOffset(name)` holds pixel corrections measured by rendering glyphs
against JetBrains Mono text — update it if you add glyphs. BT device rows all
use the plain bluetooth glyph (matches waybar).

**Font coverage lies: a codepoint in the cmap can still render wrong.** `next`
was initially f04d (fa-step-forward) — fc-query lists it as covered, but in
JetBrains Mono Nerd Font Propo it renders as a **filled square** (codepoint
collision). Always render-test new glyphs with a throwaway qs instance +
`grim` before committing them; don't trust fc-query alone.

### Workspaces pill: fixed cell widths and the silent Repeater-id trap
State of `Workspaces.qml` after the 2026-10-04 debug session (uncommitted at
the time of writing — the user reviews commits themselves).

- **A Repeater `id` is NOT resolvable inside delegates created through
  `Pill`'s default-alias Row** (`content: contentRow.data`).
  `isLast: index === wsRepeater.count - 1` compiled, loaded, and *silently*
  threw `ReferenceError: wsRepeater is not defined` on every evaluation — the
  property just reads `false` forever, so the last workspace's edge highlight
  never appeared while the first one worked (`isFirst: index === 0` doesn't
  reference the Repeater). Only trace: a WARN line in qs logs. Fix in place:
  the model array is hoisted to `readonly property var wsValues` on the pill
  root and edge-ness is derived from data (`isFirst: modelData.id ===
  root.wsValues[0].id`, `isLast: … === root.wsValues[root.wsValues.length-1].id`).
  `root` DOES resolve inside those delegates. Any future per-delegate
  "am I first/last" logic must follow this pattern, never `Repeater.count`.
- **Edge caps REMOVED (2026-10-06, user request):** the first/last delegates
  used to draw 32×32 "cap" circles so the active fill reached the pill's
  rounded ends; the user wanted first/last to fill exactly like intermediate
  cells, so the caps and their `isFirst`/`isLast` plumbing are gone. Every
  cell now sits inside the Pill's `hpadding` and fills number-sized. (If ever
  re-added: the cells CANNOT resolve a Repeater `id` — derive edge-ness from
  `root.wsValues`, see the trap above.)
- **Width contract (FINAL 2026-10-07 — the wider-active design was tried,
  reverted, re-requested, and reverted again; do NOT re-introduce it):** every
  cell is ONE fixed width, `max(34, label + 26)`, and there is no
  `Behavior on width`. Switching workspaces animates COLOR only; the pill's
  width changes exclusively when the workspace count changes (a 6th+ slot
  appearing/departing). History: waybar-parity wider-active
  (`max(44, label + 36)` + 170ms OutCubic) shipped twice — the net-zero width
  swap keeps the pill's TOTAL constant for equal-length labels, but the
  growing/shrinking fill mid-switch reads as "the pill resizing" and the user
  ultimately chose fully static geometry. Hover/idle/active widths are
  identical by design; nothing about a workspace switch moves any geometry.
- **Debug notes from that session:** `console.log` never surfaces through `qs`
  — use `console.warn`. Verify renders by pixel-scanning screenshots
  (contiguous color runs per row; accent `#f7c2d1` vs pale `pillBg` are
  near-identical at thumbnail size and eyeballing lies). The item tree can say
  "flush" while pixels say "gap" and both be right — geometry is one suspect,
  rendering is another.

### Stale Quickshell cache = invisible bar
After QML edits, a shell can map its window but paint *nothing* (wallpaper
shows through, `hyprctl layers` still lists the surface, **zero** errors in
any log). Cause: corrupt `~/.cache/quickshell` and/or
`/run/user/1000/quickshell/vfs` entries. `rm -rf` both and relaunch — cost
most of a session before being identified. 2026-10-05 addendum: it can hit a
SINGLE window after a rework (the toast stack mapped with correct geometry
and painted nothing while the rest of the shell rendered fine) — same fix.
Also: notification wrappers can die out-of-band even when `tracked` was set
(server-side lifecycle) — guard every `notif.expire()/dismiss()` call with
try/catch or the toast ticker throws "Type error is not a function".

### System usage section (SystemUsage.qml + ScreenTime.qml, 2026-10-05)

Bottom of the dashboard's calendar column, below the calendar. Layout per
user round 2: **no card background** — the profile rows and the CPU / Memory /
Disk bars blend directly into the popup (they looked "packed together" with a
bg). The section is anchored below the calendar's **worst-case (6-row)
footprint** (`CalendarPanel.maxContentHeight`) and stretched to the column
bottom, so it never moves while browsing 4/5/6-row months and never
overflows; leftover height is distributed evenly between the profile block
and the bar rows (`gap = (height − 66 − 3×28) / 3`, min 10).

- **Profile rows are fastfetch-style** (user's reference screenshot): a
  circular avatar (`assets/pfp.png`, Canvas-masked) + three value-only rows —
  distro, screen time, `up X hours, Y minutes`. The user explicitly dropped
  the "Hyprland" row ("no need for generic hyprland in there, screen time is
  fine") and asked for the verbose uptime format. Screen time stays compact
  (`2h 14m`) to parallel the reference's short middle row.
- **Rice portability**: the avatar is repo-relative
  (`Qt.resolvedUrl("assets/pfp.png")` — anchors to the QML file's own dir, no
  `~/Pictures` dependency; replace the file to change it — placeholder is a
  magick-generated silhouette). The lock screen's `profilePhotoPath` points
  at the SAME asset (the old `~/Pictures/wallpapers/final_logo.png` never
  existed and is gone for good). The distro row is parsed from `/etc/os-release` (PRETTY_NAME,
  fallback NAME, fallback "Linux") — never hardcode "Arch Linux".
- **Quickshell 0.3.1 has NO CPU/RAM/temp/disk API.** `/usr/lib/qt6/qml/Quickshell/Services/`
  has no System module and no `CpuUsage`/`Memory` types exist in any qmltypes
  (those landed in later Quickshell). Everything is polled like the OSD's
  backlight: `FileView` + Timer-driven `reload()` + parse in `onLoaded`
  (procfs/sysfs emit no inotify events — `watchChanges` is useless there).
- **Data sources**: CPU = `/proc/stat` aggregate line, usage = 1 − Δidle/Δtotal
  over the 2s poll (idle = field 4 + iowait field 5, total = first 8 fields;
  first read after open only calibrates — the OSD `armed` pattern); RAM =
  `/proc/meminfo` `MemTotal − MemAvailable` ("available", not "free", is what
  free(1)/htop count; fields are "kB" but really KiB); CPU temp = hwmon probe
  picks `k10temp|coretemp|zenpower` `temp1_input` (this box: hwmon5 k10temp),
  fallback `/sys/class/thermal/thermal_zone0/temp` (acpitz, millidegrees);
  disk = `df -B1 --output=used,size --total -x tmpfs -x devtmpfs -x efivarfs`
  once per open, parse the TOTAL row (single drive: / + /boot + /home sum);
  uptime = `/proc/uptime` first float → bootEpoch once per open, formatted per
  tick. SystemUsage polls ONLY while the dashboard is open (start/stop from
  DashPopup's `onVisibleChanged`).
- **MultiEffect maskSource is BROKEN in layer-shell windows** — the big one
  from this round. `MultiEffect { maskEnabled: true; maskSource: someItem }`
  renders NOTHING (mask-off renders fine) in the dashboard popup AND probe
  windows, with the mask item BOTH offscreen (the lock screen's x:-3000
  pattern) AND on-screen. Probes: plain Image ✓, MultiEffect without mask ✓,
  with mask ✗ — the mask texture simply never samples. The lock screen never
  caught it because its two RoundedImage usages never had a loadable image
  (photo path 404, media card commented out). `RoundedImage.qml` is therefore
  a **Canvas-drawn clip** now: hidden Image feeds `imgStatus` + natural size
  via the `sourceSize` READ-BACK (works — verified 256x256), Canvas draws the
  rounded-rect path (`arcTo`) + cover-crop `drawImage` with the URL registered
  through `canvas.loadImage()` (repeat per source change + on paint). Canvas
  is software-rasterized — works in every window type, inside `clip: true`,
  everywhere. Don't go back to maskSource for anything in this repo.
- **ScreenTime** (`IdleMonitor` from `import Quickshell.Wayland`, timeout in
  SECONDS — property is `double` s, not ms): mirrors the user's hypridle
  chain (backlight dim 300s < dpms-off 330s < lock 420s < suspend 600s), so
  isIdle tracks real screen-off almost exactly and suspend counts as off.
  On isIdle flips: bank the open stretch / reopen it, then persist. 5-min
  checkpoint Timer covers crash-survival and the midnight rollover (lazy
  check in every read/write: dayKey ≠ today → reset). An awake stretch
  spanning midnight counts entirely into the new day (accepted). The sidecar
  read/write uses a Process (`cat` / `printf > file`) — same reasoning as the
  pin sidecars (missing-file is normal first-run state; FileView callback
  timing burned us before).
- **Singleton laziness gotcha**: a pragma-Singleton component does NOTHING
  until first accessed. ScreenTime must accumulate all day even if the
  dashboard is never opened, so shell.qml calls `ScreenTime.init()` in a
  `Component.onCompleted` on ShellRoot (attached handlers work on ShellRoot;
  verified). Without that line the accumulator simply never exists.
- **QtObject roots still can't host children** (hit again while writing
  ScreenTime as a QtObject singleton: Timer/Process/IdleMonitor children →
  "Cannot assign to non-existent default property"). Root is an `Item`.
- **`Process.exec()` exists but the repo convention is `command` + `running
  = true`** — keep new code on `running = true` (ScreenTime/SystemUsage
  originally used `.exec()`, converted).
- **Glyphs** (clock F0150, monitor F0379, cpu F061A, memory F035B, disk
  F02CA, arch F303, linux F033D): picked by reading the font's own glyph
  table with fontTools (`TTFont.getBestCmap()` reverse name→codepoint on
  `/usr/share/fonts/TTF/JetBrainsMonoNerdFontPropo-Regular.ttf`), then
  render-tested via a throwaway strip window. The distro glyph maps
  os-release's name → `arch`, else the penguin `linux`. md-cpu_64_bit was
  rejected (embedded "64" text unreadable at 15px).
- **Two live-bar traps while verifying**: (1) an intermediate reload between
  two edits of the SAME feature logs errors forever after (e.g.
  `ReferenceError: dateHeader is not defined` from a binding whose target id
  landed in the next save) — count occurrences before/after a forced reload
  before treating it as real; the final files were clean. (2) When the bar
  process is dead, its log keeps existing and greps "succeed" — check
  `pgrep -x qs` / `hyprctl layers` FIRST (see below).
- **Red herring to remember**: while verifying, the "live" bar instance
  turned out to be DEAD (no qs process at all, no quickshell layers in
  `hyprctl layers`) — its log had frozen mid-session, and grepping it for
  evidence of the singleton led to a long false "ScreenTime doesn't
  materialize" chase. `pgrep -x qs` / `ps -eo comm | grep qs` FIRST, and
  `hyprctl layers`, before debugging a "stale" instance. The instance had
  also stopped hot-reloading before it died (log frozen despite saves) —
  a fresh `qs -c rice` picked everything up instantly (also cleared
  `/run/user/1000/quickshell/vfs/*` first per the stale-cache gotcha).

### Lock screen (Lockscreen.qml, 2026-10-05)


Hyprlock replacement. Runs INSIDE the main shell instance (user decision —
not a standalone `qs -p` config "for now"): a `WlSessionLock` sits unlocked
until something engages it; on success `LockState.engaged` drops and the
bar keeps running. Styling per user feedback (round 3): NOTHING sits on a
card/chip and NO text has any shadow/glow — every text is plain palette
text over the blur (the soft white MultiEffect glow was tried and
explicitly rejected as a "weird effect"); legibility is the wallpaper's
problem. The battery chip was rejected too (kept as a comment in the right
column). Password dots are 5px; fail feedback is a thin gradient border
(Canvas — Rectangle borders can't take gradients) in hyprlock's exact
fail_color (#ff6633→#ff0066, 40deg, alpha .93) that shows ONCE and fades
out over 1.8s — NO ring while verifying and NO looping animation. The fail
message lives INSIDE the field (fail_text parity): the buffer is cleared on
failure so it replaces the dots, and it hides as soon as the user types
again (effBuffer gate). The displayed failure text is ALWAYS
"Authentication failed" — pam.message goes to console.warn only (their PAM
stack's message is literally "wrong password"; the user caught the ternary
preferring it). Readability is solved by SAMPLING: a 16x9 offscreen
Canvas (`lumSampler`, loadImage + getImageData) averages the wallpaper's
luminance and flips `root.wallDark`, which drives `lockFg`/`lockFgMuted` —
light text on dark wallpapers, dark palette fg on light ones (whole-image
average — a wallpaper split bright-top/dark-bottom classifies by its mean;
threshold is the `128` in lumSampler). Lock/unlock fades are QML-side
(`lockFadeInMs`/`lockFadeOutMs`, both 500ms Linear): hyprlock's
`animation = fadeIn, 1, 5, linear` speed param is DECISECONDS — hyprutils
`getPercent()` computes `duration = 100 × speed` ms, so 5 = 0.5s, NOT 5s
(the "5s" reading cost the user a "way too slow" round; they verified by
setting the knob). The unlock fade MUST run in QML before
`LockState.engaged` drops, since a layer surface that is already destroyed
cannot be animated by compositor layer rules; keys are ignored while
`unlocking`). The fades target a `uiFade` wrapper around the UI overlays
ONLY — the wallpaper stays opaque so the surface's black backing never
shows mid-fade (fading the whole content produced a black flash). Round 8
attempted the "true" hyprlock cross-fade (transparent
`WlSessionLockSurface.color` + wallpaper inside uiFade) — it looked perfect
in preview but the user REJECTED it: on a real lock the black flash returns
on enter AND exit. Hyprlock can cross-fade because it fully controls its
own render pipeline; a Quickshell lock surface cannot replicate it. DO NOT
retry — the split fade (opaque backing, overlays-only fade) is final.
Weather, status and the keyboard-layout switcher are commented out (user
request, round 6) — their Processes at the root are commented with them;
battery stays. TWO
lifecycle traps cost a debug round (user caught it: preview worked, real
lock stayed palette-dark): (1) in the real bar the content is created with
`wallpaperPath` ALREADY set, so an `onWallUrlChanged`-only trigger never
fires — the load must also start from `Component.onCompleted`; (2) a
Canvas is NOT `available` during construction, so `getContext()` returns
null ("Unable to use getContext() at this time") — the decode must wait
for the `available` handshake and be retried (`decodePending` +
`onAvailableChanged`). Caps state: single-flight `hyprctl -j devices`
probe (1s timer guarded on `Process.running`, plus an immediate re-probe
on the CapsLock keypress in `handleKey`); the capsLock field is only
assigned when present.
- **Round-7 fixes (2026-10-06, dir-cleanup fallout)**: (1) the wallpaper
  background Image had been rebound to `Qt.resolvedUrl("../assets/pfp.png")`
  (a copy of the avatar's expression) with the real
  `"file://" + wallpaperPath` commented above it — pfp-as-wallpaper; the
  awww query + parse were never the problem, don't "fix" them. (2) The
  sampler's failure modes were ONE-DIRECTIONAL: a sample taken before the
  decode finished (or a failed load) reads all-transparent pixels whose
  0-luminance classifies the wallpaper dark forever — `sample()` now counts
  alpha≠0 coverage, retries via a 250ms Timer (5 cap, `loadImage` re-issued
  on the `available` handshake), and falls back to `wallDark = true` when
  exhausted (unloadable wallpaper = black backing = light text is right).
  (3) Classification uses Rec.709 LUMA — a blue-saturated wallpaper can
  show a bright channel-mean (~167) while its luma is ~105 → "dark" with
  light text is CORRECT for it; check with
  `magick <img> -resize 16x9! -format "%[fx:0.2126*r+0.7152*g+0.0722*b]"`,
  not `%[fx:mean]`. The photo ring (border #1b1d1f) is gone entirely.

- **0.3.1 API names**: `WlSessionLock` / `WlSessionLockSurface` in
  `Quickshell.Wayland` (NOT `SessionLock*` — those are newer). The surface
  component auto-instantiates per screen; there is NO `unlockRequested`
  signal — unlock = `locked: false`. Killing quickshell while locked bricks
  the session (protocol keeps it locked, solid color) → recovery: TTY +
  `loginctl unlock-session`.
- **`GlobalShortcut` resolves only via `import Quickshell.Hyprland`** (the
  shortcuts live in an internal module that module re-exports) — `import
  Quickshell` alone gives "GlobalShortcut is not a type" even though
  shell.qml happens to also import Hyprland.
- **A `QtObject` root cannot host children** ("Cannot assign to
  non-existent default property") — Lockscreen's root is an invisible
  `Item`. Also: `id:` values cannot contain dots.
- **Trigger wiring**: `qs:lock` GlobalShortcut (appid `qs` — standalone
  desktop tool, NOT `qs-bar`; renamed in round 8 when the lockscreen became
  standalone). From SCRIPTS (hypridle lock_cmd) the ONLY working form is the
  **dispatch request with the descriptor**:
  `hyprctl dispatch 'hl.dsp.global("qs:lock")'`. TRAPS (both cost rounds):
  plain `hyprctl dispatch global ...` / `dispatch eval` die in the Lua
  parser, and `hyprctl eval 'hl.dsp.global(...)'` returns "ok" but is a
  NO-OP — eval discards the descriptor, so the shortcut never fires (the
  user's hypridle silently failed to lock on exactly this; verified by
  popping the dashboard: eval 0 layers, dispatch 1 layer). PowerPopup
  Lock sets `LockState.engaged = true` (its `run()` takes the model entry;
  entries carry either `cmd` or `act: "lock"`).
- **NEVER guard engage() on `LockState.engaged`** (round-8 lockout, user
  caught it: the PowerPopup path set the flag first, so engage() — invoked
  BY the flag change — returned immediately: lock surfaces with stale state
  and a PAM that never started = complete lockout, no input accepted). The
  guard is the lockscreen's own `sessionActive` flag; `LockState.engaged` is
  only an external trigger mirror, and `WlSessionLock.locked` binds to
  `sessionActive && !testMode`.
- **PAM**: `PamContext` (`Quickshell.Services.Pam`) with `config: "login"` —
  literally the stack hyprlock gets (`/etc/pam.d/hyprlock` is just `auth
  include login`), so NO custom PAM file is needed (sudo unavailable in the
  agent shell; `pamConfig` property can point at a custom file later).
  Verified: `start()` → `pamMessage` "Password:" with `responseRequired:
  true`. Gotchas: `pamMessage` has NO parameters (read `message`/
  `responseRequired` off the object); `completed(result)` carries a
  `PamResult` enum (Success/Failed/Error/MaxTries) — restart `start()` after
  Failed/MaxTries, DON'T restart on Error (the `error` signal handles it);
  Enter before the prompt arrives sets `pendingSubmit`, answered on the
  first `pamMessage`. On engage, `pam.start()` failing locks anyway with an
  on-screen "PAM unavailable" message (privacy over availability).
- **MultiEffect semantics (cost a debug round, still true even though the
  text-glow was removed)**: MultiEffect does NOT hide its source — you
  must set `visible: false` yourself, and an INVISIBLE source still renders
  through the effect. `opacity: 0` on the source is the documented variant
  that KEEPS touch/click input. Anchoring the effect to the source with
  default autoPadding produced offset ghost-doubles; manual geometry +
  `autoPaddingEnabled: false` + `paddingRect` is deterministic. This now
  only matters for the wallpaper blur and the RoundedImage mask
  (photo/album art). Qt docs:
  doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html.
- **Time is 12h via manual math** (`timeText` property): Qt's `hh` is only
  12-hour when `AP` is in the SAME format string, and the AM/PM is a
  separate smaller Text here.
- **hypridle-data polls**: one 250ms `hyprctl -j devices` Process (conf's
  `cmd[update:250]` parity) feeds BOTH `capsLock` and `active_keymap` of the
  main keyboard (fields verified via jq). `hyprctl switchxkblayout all
  next` is a top-level hyprctl command — not a dispatch — so it works from
  QML despite the Lua IPC change.
- **weather.sh quirk**: the user's script prints ONLY on a cache hit; a
  fresh fetch writes `/tmp/cache/wttr_cache.txt` and prints nothing. The
  wrapper runs it then cats the cache (`sh -c 'bash "$1" >/dev/null; cat
  /tmp/cache/wttr_cache.txt'`). Started at `Component.onCompleted` AND on
  engage — the 60s timer alone missed the first minute.
- **Commented-hyprlock-feature blocks** (user verifies, then comments out
  themselves): profile photo (130px circular, `profilePhotoPath` → the repo
  asset `assets/pfp.png`; COMMENTED OUT in round 8 at the user's request,
  nudged 30px toward the password field for when it returns), weather, status
  line (invented content: vol/mic/bt — original status.sh never existed; both
  it and weather are commented out already), keyboard-layout
  switcher (commented out too), MPRIS media card (art via `trackArtUrl`,
  only while PLAYING — widget-box-color.sh parity). The battery chip was
  REJECTED in round 3 —
  it survives only as a comment in the right column. hyprlock toggles are
  properties: `hideInput`, `asteriskDots`. Design reference the user pointed
  at: end-4/dots-hyprland `ii` quickshell module (lock/polkit folders) —
  their Lock visuals live in `common/panels/lock`, `PasswordChars.qml` shows
  their per-char Material shapes.
- **Preview/testing (NEVER real-lock from the agent)**: `/tmp/locktest.qml`
  (keep out of the repo) imports the repo via `file:` URLs to `core/` + `standalone/`, applies
  colors.css to Theme, and instantiates `Lockscreen { testMode: true }` —
  the same content renders in an Overlay `PanelWindow`
  (`quickshell:lockscreen-test`), Enter SIMULATES a wrong password (no PAM),
  Esc closes when the buffer is empty. `testPreview`/`testState`/`testCaps`
  render state variants; `LOCK_FAKE_MEDIA=1` forces the media card. Screenshot
  ≥5s after launch (UPower populates ~3s — earlier shots showed no battery).
  Round-1 black screenshots were a red herring: `hyprctl layers` + magick
  pixel-scans showed the window mapped and painting; trust those over a
  single Read of a PNG.

### Wallpaper switcher (Wallswitch.qml, 2026-10-04)

skwd-wall's "Slices" picker, ported to QML minus the feature buffet. Replaces
the rofi `~/.config/rofi/wallpaper-switcher/wall-switcher.sh` flow entirely
(the script, its `.rasi` theme and the `wall_switch` variable in
`variables.lua` are dead weight now — the picker shells out to the binaries
directly).

- **Trigger**: `GlobalShortcut` appid `qs`, name `wallpaper-switcher` →
  `Popups.toggle("wall")` (its OWN appid, not `qs-bar` — the user wanted the
  picker identifiable as a desktop tool rather than a bar feature). User
  binds e.g.
  `hl.bind(mainMod .. " + W", hl.dsp.global("qs:wallpaper-switcher"))`. The
  window is instantiated at shell root via a lazy Loader (created on open,
  destroyed on close) declared AFTER `Variants` — the
  fullscreen shield is INVISIBLE (no dim; user rejected the dark backdrop:
  skwd floats over the live desktop) and must stack above the bar so a bar
  click closes the picker first, matching the other popups' convention.
- **Apply = two binaries, exact known-good args**, executed by
  `Actions.applyWallpaper(path, trans)` (core/Actions.qml — the runner MUST
  live at singleton scope, see the lazy-popups Process rule): awww
  + matugen as one `sh -c` with the path/transition passed as positional
  argv (filename-proof):
  `awww img "$1" --transition-type "$2" --transition-duration 1.2
  --transition-fps 60 && matugen image "$1" --prefer darkness --config …`.
  `$2` is a random of fade/wipe/outer/grow/random. NB: the old rofi script's
  fifth entry `slide` is NOT a valid awww 0.12.1 transition — every apply
  that rolled it failed with "invalid value 'slide'" and (via the `&&`)
  silently skipped matugen too. Keep transition values inside awww's set.
  **matugen's `config.toml` must keep `[config.wallpaper] set = false`** —
  user-verified: with `false` matugen only regenerates templates (incl. the
  `hyprctl reload` post-hook), with `true` it re-applies the wallpaper with
  its own `center` transition and would double-apply. There is NO CLI flag
  to override it (checked 4.2.0 `util/arguments.rs`). awww's non-zero exit
  short-circuits matugen so the palette can never desync from the wallpaper.
- **Data**: `find ~/Pictures/wallpapers -type f` (same ext glob as the old
  script; RECURSIVE since 2026-10-07 — wallpapers may sit in subdirectories
  of `wallDir` like `images/`, and the ext glob keeps non-image files such
  as `scripts/` out) piped to `sort`, plus
  `awww query` parsed with `(?<=image: ).*` (same as hyprlock-auto.sh). Both
  re-run on every open; selection resolves when the list lands (the query may
  arrive before or after it — `resolveSelection()` handles both orders).
- **Carousel mechanics**: 11 recycled slots each hold a stable `wallIdx`;
  `layoutSlots()` (on every `centerPos` change) keeps the indices around
  `floor(centerPos)` assigned, reassigning only far-edge slots whose opacity
  is ~0. Slot geometry is a pure function of the wrap-around distance
  `d = wallIdx - centerPos` (`signedDist`): width/shear/dim lerp toward the
  strip shape, the first strip hugs the center image's edge (`slotOffset()`),
  later ones step `stripW + gap`. **The center frame is FIXED `slotH * 16/9`**
  (user-requested: same box for every wallpaper, non-16:9 center-crops — do
  NOT bind the frame to the image's natural aspect, it rescales the whole
  row per wallpaper). **The shear is UNIFORM across all slots including the
  center** — user correction against the reference: skwd leans the whole
  plane at one angle; an earlier straighten-at-center morph was wrong. `centerPos` has a 260ms OutCubic Behavior **gated by
  `animateNav && everOpened`** — opens and Home/End must snap, or the first
  open flies across 471 entries (and `enabled` belongs on the `Behavior`,
  NOT on the `NumberAnimation` — "Cannot assign to non-existent property").
- **Geometry is derived, not fixed pixels** (user-tuned against the
  reference): `sideSlots = 4` strips per side, `margin = 5%` of screen width
  of empty desktop at the row ends, `pitch = (scrW/2 - margin - centerW/2) /
  sideSlots`, `stripW = pitch - gap` — so exactly 4 strips fit between the
  center frame and the margin on any screen width. `shearK = 0.15` (~8.5°;
  the first 0.35 was way too slanted per user). Slots beyond `|d| = 4` fade
  out by 4.5 and hide — maxSlots is 9 (the outermost pair are just invisible
  teleport targets for recycling). **The dim is NOT in QML**: the user wants
  the compositor to dim what's behind the picker via a `dimaround` layer
  rule on namespace `quickshell:wallswitch` (README setup step 4 has the
  snippet) — keep the QML shield invisible.
- **Filename chip only on the focused slot** (`visible: wallIdx ===
  selected`, not a distance gate) — side strips are unnamed like skwd; the
  selected-slot condition avoids the two-chips-at-midpoint flicker a
  `|d| < 0.5` gate would give mid-animation, and it's a pure visibility
  toggle (no image reloads involved).
- **Keys** (all user-confirmed working): Esc / arrows / `Tab`/`Backtab` /
  `Home`/`End` / Enter+Space on a focus-sink Item via `Keys.onPressed`, PLUS
  `Keys.onReturnPressed` and `Keys.onEnterPressed` — Enter did not apply
  until the specific handlers existed (Space worked all along from
  onPressed; root cause never explained). A 250ms `lastApply` guard in
  `apply()` makes a double delivery a no-op, and any unrecognized extended
  key (>= 0x01000000) `console.warn`s its code. The `dimaround` layer rule
  on `quickshell:wallswitch` is also user-confirmed.
- **Search (type-to-filter, implemented 2026-10-04):** printable keys append
  to `query` (Space still applies — only `event.text >= "!"` with no
  Ctrl/Alt/Meta counts as typing), Backspace pops, Esc clears the query
  first and closes only when it's empty. `onQueryChanged: rebuildShown()` is
  THE filter hook — without that one line, typing does nothing (it shipped
  missing once; the seed-before-load test passed because the list-load
  rebuild ran after the seed — always test the typing path with the query
  set AFTER the list is loaded). The carousel runs on `shown` — a
  filtered list of indices into `walls` (case-insensitive basename
  substring); `selected` stays a walls-index (apply/currentPath logic
  untouched) while `selectedPos` = its position within `shown` drives
  `centerPos`. Filter changes SNAP (`animateNav = false`), never slide.
  A chip above the row shows `query · N matches` only while a query is
  active; a distinct "No matches" chip covers the empty filtered set. With
  fewer matches than slots the same wallpapers repeat around the wrap —
  inherent, not a bug. Gotcha hit live: Quickshell flips `visible`
  ASYNCHRONOUSLY on the real map — a `query = ""` reset in
  `onVisibleChanged(visible=true)` ran AFTER the test seeded the query and
  clobbered it; the reset therefore lives on the CLOSE branch
  (`else if (query !== "") query = ""`).
- **Kitty stderr noise on apply, solved:** matugen's config had a stale
  `[templates.kitty]` block whose `post_hook = 'kill -SIGUSR1 $(pgrep
  kitty)'` ran on EVERY palette regen; with no kitty running `pgrep` returns
  nothing and `kill` prints its usage error, which matugen reports on stderr
  and the picker's apply-Process logs as "wallswitch: apply stderr". The
  block is commented out in `~/.config/matugen/config.toml` — if that
  warning ever returns, check for resurrected template blocks there. The
  picker deliberately logs matugen stderr (it surfaces real failures); don't
  silence it.
- **Jagged slanted edges — PARKED shader experiment, NOT in the live code.**
  Status: the user reverted the switcher to the `shearWrap` + `Matrix4x4` +
  `clip` version (edges aliased, accepted for now); `shaders/` is kept
  committed so a future session doesn't start from scratch. The conclusion
  stands: there is NO simple fix — a transformed quad's edges are rasterized
  WITHOUT anti-aliasing; `clip: true` is binary scissor/stencil;
  `layer.enabled/smooth/samples` only change texture *sampling* (the quad
  boundary stays hard — tried, did NOT fix it, don't claim otherwise);
  Quickshell 0.3.1 exposes no window-MSAA property (checked the qmltypes).
  The working-but-reverted approach: each slot = `ShaderEffect` with
  prebuilt `.qsb` shaders masking the parallelogram with a 1px `smoothstep`
  (AA verified numerically: pixel rows across the border show blended
  intermediate values). What killed it — TWO bugs shipped together in the
  rewrite and my verification only checked the border zoom, not the frame:
  1. **Mask clipped to a rectangle** (user's exact diagnosis): fragments
     outside a ShaderEffect's own rect never rasterize, and the parallelogram
     extends `k*slotH/2` px beyond it — the overhang must be added back by
     widening the effect item (negative left/right anchor margins) and
     masking at `x - pad + shear*(y - H/2)` with `pad = shearK*slotH/2`.
  2. **Lean flipped**: the old matrix's `m12 = -k` corresponds to a mask
     left edge of `pad - shear*(y - H/2)` (tops lean RIGHT); using
     `+shear*(y - H/2)` mirrors it.
  If resumed, start from `shaders/wallslot.{vert,frag}` (sources carry
  comments), recompile with
  `/usr/lib/qt6/bin/qsb --glsl "100es,440" --hlsl 50 --msl 12 -o X.qsb X`,
  and re-apply the geometry fix above BEFORE screenshotting. qsb gotchas
  (all hit live): Qt 6 ShaderEffect takes ONLY `.qsb` URLs — runtime GLSL
  strings are treated as file paths; `--glsl 100es` alone is NOT enough
  (desktop-GL tries versions 120..460 → "No GLSL shader code found"); the
  vertex shader must declare `qt_TexCoord0` (location 1) even when unused;
  uniform block = `qt_Matrix`, `qt_Opacity`, then QML custom properties in
  ALPHABETICAL order (std140, binding 0), sampler `layout(binding = 1)`.
- **Parallelogram slices: shear a clipped WINDOW, never the Image.** The
  sheared Image is ~`k*slotH` px wider than its strip; with no clip (or a
  plain `clip: true` on the slot) that content spills over the neighboring
  slots and hides their chips/strips (cost a debug round). Structure:
  outer slot → `shearWrap` Item with the `Matrix4x4` → inner window Item
  (`clip: true`) → Image + dim + border inside. The clip rect transforms
  WITH the wrapper, giving a clean leaning slice. `m12 = -k` puts the TOP
  edge to the right (right-leaning, what the user chose over skwd's
  left-lean); `m14 = k*slotH/2` pivots the shear on the vertical middle.
- **Decode cost**: `sourceSize.width` quantized to 128px steps (the slot
  width morphs continuously; an exact binding would re-decode every frame),
  `sourceSize.height: 0`, `asynchronous: true`, `cache: true`.
- **Debug pattern that paid off**: binding errors fail SILENTLY to a wrong
  value — renaming `W`/`H` (uppercase property names are illegal, an
  existing gotcha) left `slotH: Math.round(H * 0.58)` throwing
  `ReferenceError` on every eval and reading 0, with zero visual errors and
  everything else working. A temporary `console.warn` Timer dumping the slot
  tree (plus a `property alias imgItem: img` for statuses) found it in one
  run. `console.log` doesn't surface, `console.warn` does.

  run. `console.log` doesn't surface, `console.warn` does.
- **Test-instance trap**: a throwaway never runs shell.qml, so Theme keeps
  DEFAULTS — the accent border reads default pink #f7c2d1 in test
  screenshots and the matugen accent in the live bar. Don't scan for the
  wrong color when pixel-checking.

### Memory profile + lazy popups (2026-10-06, optimization branch)

Full numbers in [OPTIMIZATIONS.md](OPTIMIZATIONS.md); the load-bearing bits:

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

## Greetd Greeter companion (`greeter/`)

The repository includes a companion greetd greeter (`greeter/`) designed to mirror the bar's styling and lockscreen aesthetic. Key architectural invariants connecting quickshell to the greeter:
- **Compositor & Window Type**: The greeter runs under the lightweight `cage` kiosk compositor (`greetd.service` → `sh -c 'exec cage -s -d -- quickshell -p /etc/greetd/greeter/shell.qml >/dev/null 2>&1'`). Because Cage is a strict XDG toplevel kiosk compositor and does **not** support `zwlr_layer_shell_v1`, `greeter/shell.qml` uses `FloatingWindow { fullscreen: true }`, NOT `PanelWindow`.
- **Silent & Fast Boot**: Directing cage + quickshell stdout/stderr to `/dev/null` silences compositor and Mesa/EGL text spam on TTY 1 during boot and session handoff.
- **Shared Luminance Sampler & Transparent UI**: Like `Lockscreen.qml`, `greeter/Greeter.qml` uses a 16×9 offscreen Canvas to compute Rec.709 luma (`wallDark`) and dynamically set `lockFg` / `lockFgMuted`. The wallpaper uses the identical `MultiEffect` blur setup as `Lockscreen.qml` (`blurMax: 64`, `blur: 1.0`, `anchors.margins: -64`) over the full-resolution wallpaper. Password dots use the identical 10px size and `spacing: 3` gap as `Lockscreen.qml`. Bottom pills (SessionSelector, PowerMenu) and the user selection pill are transparent at rest and blend cleanly into the background with frosted glass popups. All interactive controls use `TapHandler` alongside `MouseArea`.
- **Wallpaper Sync**: The desktop shell updates the greeter wallpaper via an atomic symlink swap (`ln -sfn "$WALL" /var/cache/greetd/.wallpaper.tmp && mv -Tf ... /var/cache/greetd/wallpaper`), so no disk space is duplicated and the update is instant. In `quickshell/core/Actions.qml`, `applyWallpaper` and `syncGreetdWallpaper()` perform this symlink swap and sync `colors.json`. `greeter/install.sh` ensures directory traversal ACLs (`setfacl -m u:greeter:--x /home/*` and `u:greeter:rX /home/*/Pictures`).
- **Password Dots Limitation**: In the greeter's clipped horizontal Flickable, password dots do not support manual mouse dragging/scrolling (layer/kiosk surface grab limitation). Documented by requirement — do not attempt to fix.
- **Live Deployment**: The live greeter lives in `/etc/greetd/greeter/`. Editing files in `greeter/` does not affect the live system until the user runs `sudo ./greeter/install.sh`.

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
  `import "file:/home/anuj/Documents/Dev/quickshell_rice/core"` +
  `import "file:/home/anuj/Documents/Dev/quickshell_rice/popups"` (bare absolute
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
