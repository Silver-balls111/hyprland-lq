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
| `shell.qml` | Entry point. `//@ pragma UseQApplication` is **required** (tray menus need it). Hosts the two `GlobalShortcut`s (`powermenu`, `notification`), the `NotificationServer` (once, NOT per-screen — see notification gotcha) and the `Toast` window. `Variants` spawns one `Bar` per screen. |
| `Bar.qml` | 46px `PanelWindow` (layer Top). Anchors the three pills and instantiates the four `RicePopup`s + `TrayMenuPopup`. Also hosts `showTooltip()`/`hideTooltip()` which delegate to `TooltipWindow`. |
| `Workspaces.qml` | Hyprland workspaces, min 5 persistent slots (`minCount`), click switches via dispatch. Urgent workspaces tint orange. Active cell is wider than idle/hover; first/last delegates draw "cap" circles so the active fill reaches the pill's rounded ends (see Workspaces gotcha). |
| `ClockPill.qml` | Center pill: stateful bell + time (no clock glyph — removed 2026-10-04). Bell mirrors waybar's notification-module glyphs via `Notifs.unread`/`Notifs.dnd`; unread also boosts color from fgMuted to fg. Owns a `SystemClock`. Hover = date tooltip, click = dashboard popup. |
| `StatusPill.qml` | Right pill: SystemTray items, volume (scroll ±1% / click mute), mic, wifi, bluetooth, battery, power. Exposes `wifiRightX`/`btRightX`/`powerRightX` so Bar can anchor popups under the right icons — **do not delete these**, the popups depend on them. |
| `Popups.qml` (singleton) | `active` = name of the open popup ("" / "clock" / "wifi" / "bt" / "power" / "tray"). Single source of truth for popup exclusivity. `lastDismiss` guards against the outside-click that dismissed a popup re-triggering a toggle. |
| `RicePopup.qml` | Base class for dash/wifi/bt/power popups: full-screen transparent layer-shell "shield", visible rounded panel anchored inside it, closes on outside click / `Esc` / `Popups.active` change. `panelWidth` + optional `panelHeight` (0 = auto-size from content); panel x is clamped to the screen. |
| `WifiPopup.qml` | Wi-Fi toggle, networks sorted by signal (connected first), max 5 visible + scroll, inline password prompt (`connectWithPsk`). |
| `BluetoothPopup.qml` | Adapter toggle, devices (paired first), pair/connect/disconnect on click. |
| `PowerPopup.qml` | Power Off / Reboot / Suspend / Log Out / Hibernate / Lock (6 rows, 5 visible + scroll). Commands + letter keybinds mirror `~/.config/wlogout/layout`; grabs exclusive keyboard while open (`grabKeys`). |
| `DashPopup.qml` | Clock-click dashboard (replaces the old `CalendarPopup`): calendar column (left, 310px) + hairline divider + notifications column (right), fixed `panelHeight` 540 so a playing media card only takes space from the list. `popupName: "clock"`, anchored centered on the clock pill. |
| `CalendarPanel.qml` | Month grid + weekday/date header, extracted verbatim from the old `CalendarPopup`; `resetMonth()` called by DashPopup on every open. |
| `NotifsPanel.qml` | Right column of the dashboard: MPRIS player card(s) docked on top (`Mpris.players` filtered to non-stopped), notification history ListView (rows show a hover ✕ — visual only, the row MouseArea handles the click and removes the entry), bell "No Notifications" empty state, footer with DND `Toggle` + `Clear`. |
| `Notifs.qml` (singleton) | Notification history (plain JS snapshots, capped 30, newest first), `dnd`, current `toast` entry, `push/remove/clearAll/closeToast`. `push` sets `n.tracked = true` — see notification gotcha. |
| `Toast.qml` | Top-right toast banner (small mapped-only window, TooltipWindow pattern). Timer mirrors the user's old swaync timings: 2s low / 4s normal / 6s critical; app-supplied `expireTimeout` (ms) wins when > 0, clamped 2–15s. Hidden while DND or the dashboard is open. Click = dismiss. |
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
- **OSD protocol from the user's volume/brightness scripts** (~/.config/hypr/
  scripts/volume.sh, brightness.sh): they send `notify-send -e
  -h string:x-canonical-private-synchronous:<tag> -h int:value:<pct>
  -i <png from ~/.config/swaync/icons>`. `Notifs.push` detects the sync hint
  (or `n.transient`) and treats such notifications as OSD feedback: toast
  replaces the current one, no history, no unread count. `osdTag`/`osdValue`
  are kept on the entry for the future in-quickshell OSD (brightness/volume
  slider rendering) — that's the intended replacement for these scripts.
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
- `shell.qml` hosts a `FileView` watching `~/.config/waybar/colors.css` (the
  matugen template output waybar consumed). Chain: `watchChanges: true` →
  `onFileChanged: reload()` → `onLoaded: Theme.applyPaletteCss(text())` →
  Theme color properties update → every binding follows. Verified live with
  BOTH write styles (in-place and sed -i rename) — pixel-sampled transitions.
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
  roles — don't give them matugen roles. If the waybar directory is ever
  deleted, point the template output elsewhere and update the path.
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
  QML file run the same way (keep test files out of this repo).
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
