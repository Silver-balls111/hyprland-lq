# AGENTS.md — agent notes for quickshell_rice

Reference for AI agents / new sessions working on this repo. Read this before
changing anything — most of it is the residue of real debugging sessions.
`README.md` covers user-facing usage; this covers architecture, quirks and
conventions.

## What this is

A floating pink "pill" status bar for **Arch Linux + Hyprland ≥ 0.56**, built
for **Quickshell 0.3.1** (QML). Layout: workspaces (left), clock + calendar
(center), tray/volume/mic/wifi/bluetooth/battery/power (right). The design and
iconography deliberately mirror the user's waybar setup —
`~/.config/waybar/config.jsonc` is the reference for Nerd Font glyph codepoints
and per-state icon behavior.

Run: `qs -p ~/Documents/Dev/quickshell_rice/shell.qml` (Quickshell hot-reloads
the config on every file save — you do not need to restart to test QML edits).

## File map

| File | Role |
|---|---|
| `shell.qml` | Entry point. `//@ pragma UseQApplication` is **required** (tray menus need it). `Variants` spawns one `Bar` per screen. |
| `Bar.qml` | 46px `PanelWindow` (layer Top). Anchors the three pills and instantiates the four `RicePopup`s + `TrayMenuPopup`. Also hosts `showTooltip()`/`hideTooltip()` which delegate to `TooltipWindow`. |
| `Workspaces.qml` | Hyprland workspaces, min 5 persistent slots (`minCount`), click switches via dispatch. Urgent workspaces tint orange. Active cell is wider than idle/hover; first/last delegates draw "cap" circles so the active fill reaches the pill's rounded ends (see Workspaces gotcha). |
| `ClockPill.qml` | Center pill: clock + bell glyphs. Owns a `SystemClock`. Hover = date tooltip, click = calendar popup. |
| `StatusPill.qml` | Right pill: SystemTray items, volume (scroll ±1% / click mute), mic, wifi, bluetooth, battery, power. Exposes `wifiRightX`/`btRightX`/`powerRightX` so Bar can anchor popups under the right icons — **do not delete these**, the popups depend on them. |
| `Popups.qml` (singleton) | `active` = name of the open popup ("" / "clock" / "wifi" / "bt" / "power" / "tray"). Single source of truth for popup exclusivity. `lastDismiss` guards against the outside-click that dismissed a popup re-triggering a toggle. |
| `RicePopup.qml` | Base class for wifi/bt/power/calendar popups: full-screen transparent layer-shell "shield", visible rounded panel anchored inside it, closes on outside click / `Esc` / `Popups.active` change. |
| `WifiPopup.qml` | Wi-Fi toggle, networks sorted by signal (connected first), max 5 visible + scroll, inline password prompt (`connectWithPsk`). |
| `BluetoothPopup.qml` | Adapter toggle, devices (paired first), pair/connect/disconnect on click. |
| `PowerPopup.qml` | Power Off / Reboot / Suspend / Log Out / Hibernate / Lock (6 rows, 5 visible + scroll). Commands + letter keybinds mirror `~/.config/wlogout/layout`; grabs exclusive keyboard while open (`grabKeys`). |
| `CalendarPopup.qml` | Month grid, opens on the current month every time, click-opened (no hover behavior). |
| `TrayMenuPopup.qml` | Themed DBusMenu renderer for tray items (`QsMenuOpener`), one submenu drill-down level with a Back row. Scroll position resets on every open. |
| `TooltipWindow.qml` | Small floating window rendering ONE hover tooltip; positioned via layer-shell margins. Only mapped while showing. |
| `NIcon.qml` | Fixed-square `Text` rendering one Nerd Font glyph from `Icons`. |
| `Icons.qml` (singleton) | Glyph codepoint map + `batteryGlyph(level, charging)` + per-glyph `yOffset()` vertical corrections. |
| `Theme.qml` (singleton) | All colors, fonts (`fontFamily` = JetBrains Mono, `nerdFont` = JetBrains Mono Nerd Font Propo), metrics. |
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

### Tooltip positioning
The tooltip window is top+left anchored and positioned via `margins`. It must
set `exclusionMode: Normal; exclusiveZone: -1`, otherwise Hyprland shifts it
below the bar's 46px exclusive zone (~46px too low). Vertical gap convention:
pill bottom + 6px; all status tooltips pass the whole pill as the `yItem` so
every tooltip sits at one height.

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
- QML files in this dir require a `qmldir` entry each; singleton + component
  listing the same file twice fails to load; QML property names cannot start
  with an uppercase letter.

### Icons are Nerd Font glyphs, not fonts-of-opportunity
All codepoints in `Icons.qml` were taken verbatim from the user's waybar config
(battery level/charging arrays, volume low/high/muted, mic, wifi, bluetooth,
clock, bell). Power intentionally uses the md power glyph (font-metric
alignment), not the ⏻ text char. `Icons.yOffset(name)` holds pixel corrections
measured by rendering glyphs against JetBrains Mono text — update it if you add
glyphs. BT device rows all use the plain bluetooth glyph (matches waybar).

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
  point.
- Live data looks "wrong" sometimes because it *is* live: volume 0% + muted
  icon means the sink actually is, battery follows the real battery (it drains
  between screenshots), bluetooth icon flips with adapter state.
- Debugging loop that works: `qs -p <file-or-dir>` in background, read stderr /
  `/run/user/1000/quickshell/<id>/log.qslog`, screenshot with hyprshot + crop
  with `magick`. Non-visual singletons/components can be probed with a throwaway
  QML file run the same way (keep test files out of this repo).
- If a newer Quickshell lands in Arch `extra` (>0.3.1), re-verify this config
  before assuming it still works — deprecation warnings are the first sign.
