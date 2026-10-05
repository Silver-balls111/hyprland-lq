# AGENTS.md — agent notes for quickshell_rice

Reference for AI agents / new sessions working on this repo. Read this before
changing anything — most of it is the residue of real debugging sessions.
`README.md` covers user-facing usage; this covers architecture, quirks and
conventions.

## What this is

A floating pill bar for **Arch Linux + Hyprland ≥ 0.56**, built for
**Quickshell 0.3.1** (QML). Layout: workspaces (left), clock + bell (center),
tray/volume/mic/wifi/bluetooth/battery/power (right). Colors are not
hardcoded — the palette is recolored live from the wallpaper via matugen
(defaults = the original pink rice). The design and iconography mirror the
user's waybar setup — `~/.config/waybar/config.jsonc` is the reference for
Nerd Font glyph codepoints and per-state icon behavior.

Run: `qs -p ~/Documents/Dev/quickshell_rice/shell.qml` (Quickshell hot-reloads
the config on every file save — you do not need to restart to test QML edits).

## File map

| File | Role |
|---|---|
| `shell.qml` | Entry point. `//@ pragma UseQApplication` is **required** (tray menus need it). Hosts the `GlobalShortcut`s (`powermenu` + `notification` under appid `qs-bar`, `wallpaper-switcher` under appid `qs`), the `NotificationServer` (once, NOT per-screen — see notification gotcha), the palette `FileView` (repo-local `colors.css`) and the `Toast`, `Osd` and `Wallswitch` windows. `Variants` spawns one `Bar` per screen (declared BEFORE `Wallswitch` so the picker's invisible input shield stacks above the bar). |
| `Bar.qml` | 46px `PanelWindow` (layer Top). Anchors the three pills and instantiates the four `RicePopup`s + `TrayMenuPopup`. Also hosts `showTooltip()`/`hideTooltip()` which delegate to `TooltipWindow`. |
| `Workspaces.qml` | Hyprland workspaces, min 5 persistent slots (`minCount`), click switches via dispatch. Urgent workspaces tint orange. Active cell is wider than idle/hover; first/last delegates draw "cap" circles so the active fill reaches the pill's rounded ends (see Workspaces gotcha). |
| `ClockPill.qml` | Center pill: stateful bell + time (no clock glyph — removed 2026-10-04). Bell mirrors waybar's notification-module glyphs via `Notifs.unread`/`Notifs.dnd`; unread also boosts color from fgMuted to fg. Owns a `SystemClock`. Hover = date tooltip, click = dashboard popup. |
| `StatusPill.qml` | Right pill: SystemTray items, volume (scroll ±1% / click mute), mic, wifi, bluetooth, battery, power. Exposes `wifiRightX`/`btRightX`/`powerRightX` so Bar can anchor popups under the right icons — **do not delete these**, the popups depend on them. |
| `Popups.qml` (singleton) | `active` = name of the open popup ("" / "clock" / "wifi" / "bt" / "power" / "tray" / "wall"). Single source of truth for popup exclusivity. `lastDismiss` guards against the outside-click that dismissed a popup re-triggering a toggle. |
| `RicePopup.qml` | Base class for dash/wifi/bt/power popups: full-screen transparent layer-shell "shield", visible rounded panel anchored inside it, closes on outside click / `Esc` / `Popups.active` change. `panelWidth` + optional `panelHeight` (0 = auto-size from content); panel x is clamped to the screen. |
| `ClipboardPopup.qml` | Clipboard history panel (cliphist backend, rofi picker replacement): search + category chips, preview cards, decode-on-demand thumbnails, pin sidecar. See its section below. |
| `WifiPopup.qml` | Wi-Fi toggle, networks sorted by signal (connected first), max 5 visible + scroll, inline password prompt (`connectWithPsk`). |
| `BluetoothPopup.qml` | Adapter toggle, devices (paired first), pair/connect/disconnect on click. |
| `PowerPopup.qml` | Power Off / Reboot / Suspend / Log Out / Hibernate / Lock (6 rows, 5 visible + scroll). Commands + letter keybinds mirror `~/.config/wlogout/layout`; grabs exclusive keyboard while open (`grabKeys`). |
| `DashPopup.qml` | Clock-click dashboard (replaces the old `CalendarPopup`): calendar column (left, 310px) + hairline divider + notifications column (right), fixed `panelHeight` 540 so a playing media card only takes space from the list. `popupName: "clock"`, anchored centered on the clock pill. |
| `CalendarPanel.qml` | Month grid + weekday/date header, extracted verbatim from the old `CalendarPopup`; `resetMonth()` called by DashPopup on every open. |
| `NotifsPanel.qml` | Right column of the dashboard: MPRIS player card(s) docked on top (`Mpris.players` filtered to non-stopped), notification history ListView (rows show a hover ✕ — visual only, the row MouseArea handles the click and removes the entry), bell "No Notifications" empty state, footer with DND `Toggle` + `Clear`. |
| `Notifs.qml` (singleton) | Notification history (plain JS snapshots, capped 30, newest first), `dnd`, current `toast` entry, `push/remove/clearAll/closeToast`. `push` sets `n.tracked = true` — see notification gotcha. |
| `Toast.qml` | Top-right toast banner (small mapped-only window, TooltipWindow pattern). Timer mirrors the user's old swaync timings: 2s low / 4s normal / 6s critical; app-supplied `expireTimeout` (ms) wins when > 0, clamped 2–15s. Hidden while DND or the dashboard is open. Click = dismiss. |
| `Wallswitch.qml` | Slanted wallpaper picker (skwd-wall "Slices" look, right-leaning) floating over the live desktop — NO dim backdrop, invisible input shield. 9-slot recycled carousel (4 strips per side), type-to-search, preview-first UX; applies via the `awww` + `matugen` binaries directly — the rofi `wall-switcher.sh` is retired (see its section below). |
| `shaders/` | Prebuilt `.qsb` shaders for Wallswitch's slot rendering (AA'd parallelogram mask). Sources kept alongside; recompile command in the wallpaper section. |
| `TrayMenuPopup.qml` | Themed DBusMenu renderer for tray items (`QsMenuOpener`), one submenu drill-down level with a Back row. Scroll position resets on every open. |
| `TooltipWindow.qml` | Small floating window rendering ONE hover tooltip; positioned via layer-shell margins. Only mapped while showing. |
| `NIcon.qml` | Fixed-square `Text` rendering one Nerd Font glyph from `Icons`. |
| `Icons.qml` (singleton) | Glyph codepoint map + `batteryGlyph(level, charging)` + per-glyph `yOffset()` vertical corrections. |
| `Theme.qml` (singleton) | Fonts (`fontFamily` = Rubik for all text, `nerdFont` = JetBrains Mono Nerd Font Propo for glyphs), the single `textSize` token (14.5 — every non-icon Text uses it, nothing bold), metrics, and the palette: color properties with pink-rice defaults that `applyPaletteCss()` overlays from matugen (see palette gotcha). |
| `Pill.qml` | Base rounded pill; declared children go into an inner Row. `rowX` exposed for popup anchoring. |
| `SignalBars.qml`, `Toggle.qml` | Wifi signal bars, on/off switch (pure QML, no Controls styling). |
| `qmldir` | **Every** component must be listed here (singletons + types) — see gotchas. |

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
  is `~/.config/quickshell/topbar` → `qs -c topbar`.
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

### Palette is matugen-driven + fonts are uniform (2026-10-04)
- `shell.qml` hosts a `FileView` watching `<repo>/colors.css` — since
  2026-10-04 the matugen template lives IN this repo
  (`[templates.quickshell]` in `~/.config/matugen/config.toml`, output
  `~/Documents/Dev/quickshell_rice/colors.css`; the old
  `~/.config/waybar/colors.css` path and its `[templates.waybar]` block are
  retired — the user comments the waybar block out whenever they get to it).
  Chain: `watchChanges: true` →
  `onFileChanged: reload()` → `onLoaded: Theme.applyPaletteCss(text())` →
  Theme color properties update → every binding follows. Verified live with
  BOTH write styles (in-place and sed -i rename) — pixel-sampled transitions.
- **matugen 4.2 config traps**: the `[config.wallpaper]` section must EXIST
  even when it only says `set = false` — commenting the whole block out
  aborts every matugen invocation with "missing field `config`", and the
  section's `command`/`arguments` fields are required too ("missing field
  `command`") even though they're never executed while `set = false`. Both
  were hit live when the block got fully commented out — every apply fails
  until it's restored.
- **FileView traps**: the public `text` is a FUNCTION that shadows the
  internal property (`text()` — passing bare `text` hands the parser a
  function object and it silently matches nothing); `watchChanges` fires
  `fileChanged` but does NOT re-read by itself — call `reload()`; and never
  declare two `onFileChanged`/`onLoaded` handlers (QML: "Property value set
  multiple times" → whole config fails to load while the old engine keeps
  running, which makes every later edit look like it "did nothing").
- Role mapping in `applyPaletteCss`: `secondary` → pillBg/popupBg
  (translucent), `secondary_fixed` → pillHover/accent/accentSoft,
  `on_secondary` → fg, `error` → urgent, `error_container` → danger
  (dark tone, readable as text on light pills). Derived tones (fgMuted,
  track, divider, border, rowHover, inputBg) stay formulaic on top of the
  roles — don't give them matugen roles.
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

### Workspaces pill: edge caps, per-state widths, and the silent Repeater-id trap
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
- **Edge caps:** the first/last delegate each own a 32×32 circle
  (`radius: height/2`) positioned so its semicircle coincides exactly with the
  pill's rounded cap (first: `x: -root.hpadding`; last:
  `x: width - height + root.hpadding` — verified 0px over/underhang by pixel
  scan). They exist because simply deleting the Pill's `hpadding` would drag
  the HOVER fill to the pill ends too, and the user explicitly wants hover
  number-sized. Caps light ONLY for the active workspace
  (`opacity: isActive ? 1 : 0` + 130ms fade). An earlier `color.a > 0` gate
  also lit them on hover/urgent — rejected by the user. Cap `color` binds to
  the cell's color so it inherits the ColorAnimation for free.
- **Width contract (user-specified, matched against their waybar):** idle and
  hover share `max(34, label + 26)`; the ACTIVE cell is wider,
  `max(44, label + 36)`, animated 170ms OutCubic. Switching swaps the two
  widths between cells, so the pill's total width stays constant for
  equal-length labels; a small fill motion mid-switch is inherent and the user
  accepts it (their waybar shows the same artifact, subtler). Hover must never
  change width and must never reach the pill's ends.
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
most of a session before being identified.

### Clipboard panel (ClipboardPopup.qml, 2026-10-05)

Rofi clipboard picker replacement on the existing `wl-paste --watch cliphist
store` daemon — the daemon and cliphist db are never touched by the shell.

- **Trigger**: `GlobalShortcut` appid `qs-bar`, name `clipboard` →
  `Popups.toggle("clip")`; instantiated in `Bar.qml` with
  `anchorX: bar.width / 2` (that line + `centerOnAnchor` are the position
  knobs; panel size knobs sit at the top of ClipboardPopup.qml).
- **Data**: one `cliphist list` per open. Lines are `id\tpreview`
  (tab-separated); multi-line continuations don't match `^\d+\t` and are
  skipped. Categories: image when the preview starts with `[[ binary data `
  (header is `[[ binary data <size-with-unit> <ext> <W>x<H> ]]` — the size
  token can contain a space, so the regex is lazy: `.*? (\w+) (\d+)x(\d+)`),
  link on `^https?://`, else text. `<meta http-equiv=` previews are skipped
  (HTML title junk, same as the user's rofi script). Everything after this
  is in-memory JS filtering — no watchers, no per-keystroke processes.
- **Decode on demand ONLY**: restore (`printf "%s\n" "$raw" | cliphist
  decode | wl-copy` — pipe is binary-safe), delete (same stdin shape), and
  image thumbnails (first visible render decodes to
  `~/.cache/quickshell_rice/clipboard-<id>.<ext>`, persistent → later opens
  free; a `thumbs` id-array reassignment drives the Image source bindings —
  mutating an array in place would NOT). Expanded text decodes capped at
  64KB (`head -c`). Search matches previews only (~100 chars) — full-content
  search would decode 200 entries per keystroke.
- **Pins**: sidecar `~/.cache/quickshell_rice/clipboard-pins`, one id per
  line, written via a Process. Read it with a Process too (`cat`, missing
  file = empty output) — the FileView failed-load callback timing once
  silently reverted a pin race-style; the Process read is deterministic.
  Pinned ids sort first via a stable sort. Pruned ids vanish silently.
- **Buttons are mouse-only by design**: ⤢/☆/✕ are plain MouseAreas — never
  focused, not in the tab order, no keybinds. Keyboard exists solely to
  iterate cards (fast list walking): Tab/Backtab/Up/Down move, Enter
  restores the selected card. The ✕ is hover-only and its hovered state
  must NOT live in the button Repeater's model array (it would rebuild the
  buttons every time the mouse crosses a row) — the delegate reads the row
  hover itself. Link cards have no ⤢ (nothing to expand).
- **Space types a space in the search field** (deviation from the original
  plan's "Space restores" — a visible search field must accept spaces);
  Enter restores. `searchText` is an ALIAS of the TextField's text — the
  filter binding reads it, so typing filters with zero glue code; the
  open-reset clears the FIELD (a separate `searchText` state var once
  diverged from the field: filter ran while the field looked empty).
- **TextField key handling**: arrows/Tab must be intercepted via
  `Keys.onPressed` (there is no `Keys.onTabPressed` attached handler);
  Left/Right/Home/End stay unintercepted for cursor movement. First Esc
  clears the search, second closes — and the FIELD closes explicitly
  (relying on the event bubbling from the field to the body's
  `Keys.onEscapePressed` did not work in practice).
- **Fixes from the first user round — recurring QML traps, do not rediscover**:
  - Click priority: the row MouseArea must be declared FIRST in the delegate
    (lowest z) — declared last it sat ON TOP of the button column and
    swallowed every button click as "restore". Card hover then comes from a
    passive `HoverHandler`, NOT the MouseArea: a covered MouseArea loses
    hover, so the hover-only ✕ would vanish the moment the mouse reached it.
  - `Column`/`Row` layout SKIPS invisible children — a hover-only ✕ toggled
    with `visible:` resizes every card on hover. Reserve the slot with
    `opacity` + `enabled` instead.
  - ListView is a Flickable: it has NO padding properties (`rightPadding` →
    "Cannot assign to non-existent property"). Clear the attached scrollbar
    with an explicit delegate width.
  - Links: `Theme.accent` is unreadable on light palettes (near-white on
    white insets). Adaptive via a small `lum()` helper in ClipboardPopup:
    accent only when |lum(accent) − lum(popupBg)| > 0.35, else fg + underline.
  - Expand-button rule: cliphist marks truncated previews with a trailing
    `…` — short items get NO expand button; an expanded item shows the
    shrink glyph (f066) instead of expand (f065). Images always have it.
  - Live refresh: a 2s Timer re-runs `cliphist list` while the panel is open
    (parse ~1ms) so new copies appear without reopening; `parseList` must
    NOT reset `selIndex` (the poll would yank the selection to the top —
    only the open path resets it).

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
  window is instantiated once at shell root AFTER `Variants` — the
  fullscreen shield is INVISIBLE (no dim; user rejected the dark backdrop:
  skwd floats over the live desktop) and must stack above the bar so a bar
  click closes the picker first, matching the other popups' convention.
- **Apply = two binaries, exact known-good args**: one `sh -c` `Process`,
  path/transition passed as positional argv (filename-proof):
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
- **Data**: `find ~/Pictures/wallpapers/images -maxdepth 1 -type f` (same ext
  glob as the old script, ~472 files, flat) piped to `sort`, plus
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
  a day and pixel-overlapped the real `qs -c topbar` bar invisibly.
- Popup layout can be verified without clicking the bar: run a second
  throwaway `qs` instance from /tmp that imports the repo via
  `import "file:/home/anuj/Documents/Dev/quickshell_rice"` (bare absolute
  paths are rejected — the file: URL is mandatory), flips
  `Popups.active = "<name>"` in `Component.onCompleted` (optionally seeding
  singleton state like `Notifs.history` first), then grim-crops the panel
  region. Two instances coexist fine as long as the throwaway has no
  `NotificationServer`.
- If a newer Quickshell lands in Arch `extra` (>0.3.1), re-verify this config
  before assuming it still works — deprecation warnings are the first sign.
