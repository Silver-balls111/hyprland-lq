# quickshell_rice

> Humans: start with **[developers.md](developers.md)** — architecture, conventions and workflows.
> Agent/AI sessions: read **[AGENTS.md](AGENTS.md)** first — debugging history and gotchas.

A Quickshell desktop shell for **Arch Linux + Hyprland ≥ 0.56**, built for **Quickshell 0.3.1**.
One process replaces waybar (the pill bar), swaync (notifications + dashboard), hyprlock
(lock screen), wlogout (power menu) and the rofi pickers (wallpaper, tray menus).
Colors are not hardcoded — matugen recolors everything live from the wallpaper
(pink is the fallback palette).

> Hyprland 0.56 replaced the IPC dispatch syntax with Lua (`hl.dsp.*`). This bar
> sends the new syntax and falls back to the old one on Hyprland < 0.56
> (auto-detected via `hyprctl version` at startup).

## Dependencies

| Package | Why |
|---|---|
| `quickshell` 0.3.1 | The shell runtime (`qs`) |
| `hyprland` ≥ 0.56 | Window manager (Lua config) |
| `ttf-jetbrains-mono-nerd` | All icon glyphs (Nerd Font Propo) |
| `ttf-rubik-vf` | All text (variable weight) |
| `matugen` + `awww` | Palette generation from the wallpaper |
| `networkmanager` | Wi-Fi module |
| `vicinae` | Clipboard history (`SUPER+V`) — not part of this shell |
| `upower` | Battery module |
| `pipewire` + `wireplumber` | Volume/mic modules |
| `bluez` | Bluetooth module |

An MPRIS-capable player (Firefox, mpv, …) makes the dashboard's media card appear.

## Setup in a fresh Hyprland session

1. **Get the shell running**
   ```sh
   qs -p ~/Dev/hyprland-lq/quickshell/shell.qml
   ```
   or register it as a named config once, then use `qs -c rice`:
   ```sh
   mkdir -p ~/.config/quickshell
   ln -s ~/Dev/hyprland-lq/quickshell ~/.config/quickshell/rice
   qs -c rice
   ```
   Quickshell hot-reloads on every file save — tweaking QML needs no restart.

2. **Autostart** — in `~/.config/hypr/config/autostart.lua` (replacing any
   swaync/waybar lines):
   ```lua
   hl.exec_cmd("qs -c rice")
   ```

3. **Keybinds** — in `~/.config/hypr/config/keybinds.lua` (the bar registers
   two global shortcuts under appid `qs-bar`; the wallpaper picker is its own
   desktop tool and registers under `qs`):
   ```lua
   hl.bind(mainMod .. " + X", hl.dsp.global("qs-bar:powermenu"))          -- power popup
   hl.bind(mainMod .. " + N", hl.dsp.global("qs-bar:notification"))       -- dashboard
   hl.bind(mainMod .. " + W", hl.dsp.global("qs:wallpaper-switcher"))     -- wallpaper picker
   hl.bind("SUPER + L", hl.dsp.global("qs:lock"))                     -- lock screen
   ```
   The OSD watches real device state, so volume/brightness keys need no helper
   scripts — call the tools directly (scripts from a swaync setup are fully
   optional; volume is capped at 100% by the bar either way):
   ```lua
   hl.bind("XF86AudioRaiseVolume",
       hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
       { locked = true, repeating = true })
   hl.bind("XF86MonBrightnessUp",
       hl.dsp.exec_cmd("brightnessctl -q set 5%+"),
       { locked = true, repeating = true })
   ```

4. **Layer rules** — the bar's layer namespace is `quickshell:bar` (popups:
   `quickshell:popup`, toast: `quickshell:toast`, tooltips:
   `quickshell:tooltip`, wallpaper picker: `quickshell:wallswitch`). Blur and
   the picker's around-dim are optional, in `window-rules.lua`:
   ```lua
   hl.layer_rule({
       name = "qs:top-bar",
       match = { namespace = "quickshell:bar" },
       blur = true, blur_popups = true, ignore_alpha = 0.5,
   })
   -- dims the desktop behind the wallpaper picker (compositor-side)
   hl.layer_rule({
       name = "qs:wallswitch-dim",
       match = { namespace = "quickshell:wallswitch" },
       dimaround = true,
   })
   ```
   Popups/toasts need no opacity rule — they are opaque by design, and
   `hl.layer_rule` has no `opacity` field anyway.

5. **Palette (matugen)** — the bar reads the InioX matugen-themes quickshell
   flow: matugen renders a JSON palette that `core/Colors.qml` watches:
   ```toml
   [templates.quickshell]
   input_path = '~/.config/matugen/templates/quickshell.json'
   output_path = '~/.local/state/quickshell/generated/colors.json'
   ```
   No `post_hook` needed — the bar watches the JSON and recolors live. Run
   matugen once against your wallpaper (`matugen image <wallpaper>` or the
   wallpaper picker's apply); until then a snapshot fallback palette shows.
   NB: keep the `[config.wallpaper]` section present even with
   `set = false` — matugen 4.2 aborts with "missing field" if the block or
   its `command`/`arguments` fields are removed.

6. **Notifications** — this bar **is** the notification daemon (toasts +
   dashboard history). Make sure no other daemon autostarts: remove `swaync`,
   `dunst`, `mako`, `fnott` from autostart. If toasts ever stop appearing,
   check who owns the DBus name — `busctl --user list | grep
   freedesktop.Notifications` — and kill the other owner; quickshell
   re-registers automatically. If a GNOME session is ever open, its standalone
   notification daemon steals this name (guarded by
   `~/.config/dbus-1/services/org.gnome.Shell.Notifications.service` with
   `Exec=/bin/false`).

7. **Lock screen** (hyprlock replacement) — blurred current wallpaper, 12h
   clock + date, PAM password field, battery/weather/status and a media card.
   It runs inside the bar instance and engages through the `qs:lock`
   shortcut (bind shown in step 3; the power menu's Lock action engages it
   too). Auth uses `/etc/pam.d/login` — the same PAM stack hyprlock's config
   includes — so no new PAM file is needed. For hypridle, scripts can't use
   `hyprctl dispatch global` (Lua parser), but the eval socket works — in
   `~/.config/hypr/hypridle.conf`:
   ```ini
   lock_cmd = hyprctl dispatch 'hl.dsp.global("qs:lock")'   # NOTE: dispatch, NOT eval — eval discards the descriptor (no-op)
   ```
   (`loginctl lock-session` → hypridle → that command; re-fires are no-ops.)
   If the password is ever rejected with PAM broken: switch to a TTY
   (Ctrl+Alt+F2) and run `loginctl unlock-session`. To preview without
   locking, run a throwaway instance that sets `testMode: true` (see
   docs/agents/lockscreen.md); the widgets you don't want are self-contained
   blocks at the bottom of `standalone/Lockscreen.qml` — comment them out like you did
   in hyprlock.conf.

## Features

| Element | Behavior |
|---|---|
| Workspaces (1–5+) | Click to switch. Always shows at least 5 slots (extra empty slots create the workspace on click); more appear if you use more. The active workspace's pill widens with the accent fill; a workspace with a window requesting attention is tinted until visited. |
| Clock pill | Stateful bell + time. The bell mirrors waybar's notification icons: quiet = plain bell, unread notifications = ringing bell (highlighted), DND = bell-sleep variants. Click opens the **dashboard**: month calendar (left) + notifications with a media player card (right). Always opens on the current month; the player card shows track info with prev/play/next when something is playing. Below the calendar sits a **profile section**: your avatar (drop any image at `assets/pfp.png` in the rice folder to replace the placeholder) next to your distro, today's screen time (resets at midnight; screen-off mirrors the hypridle 5.5-min DPMS timeout, so inhibitors and suspend count correctly) and uptime, then CPU (percentage + temperature), Memory and total Disk bars. Closes on outside click, `Esc`, or re-click. |
| Notifications | Quickshell is the notification daemon (replaces swaync). Notifications appear as a top-right **toast banner** (2s low / 4s normal / 6s critical, app-supplied timeouts respected; click to expand the full body — the timer pauses while you read — ✕ dismisses) and land in the dashboard's history (last 30; **click a row to expand/collapse its full text** — it grows downward only, and removing one row never collapses the others; ✕ removes with a swipe-out; `Clear` wipes them). **Do Not Disturb** silences toasts but keeps history. |
| OSD | Volume / Microphone / Brightness indicator — a rounded pill at the top-right (icon + name + percentage + animated bar) that pops on any change of the underlying state: your keybinds (`wpctl`, `brightnessctl`, or the old scripts), or the bar's volume scroll. **Volume is hard-capped at 100%** (anything setting it higher is clamped back). Hides 1s after the last change; shows even while the dashboard is open. App-generated OSD-style notifications (`x-canonical-private-synchronous` hint) are dropped so they never double up with the native OSD. |
| System tray | Real StatusNotifier tray with menus (right-click), primary action (left-click) and scroll actions. Tray menus are keyboard-navigable too: `Tab`/arrows move (skipping separators and greyed-out entries), `Enter` activates or drills into a submenu, `Backspace`/`Left` goes back, `Esc` closes. |
| Volume | Scroll = ±1%, click = mute/unmute. Mirrors wpctl state. |
| Mic | Scroll = ±2%, click = mute/unmute. |
| Wi-Fi | Icon reflects the connected network's signal strength (outline when the radio is on but disconnected). Click opens a **dropdown**: toggle Wi-Fi, up to 5 networks visible with scroll, sorted by signal (connected first), each row's bars showing its live strength. Click to connect — secured networks ask for a password inline. Hover tooltip shows SSID + signal. Keyboard: `Tab`/arrows move the selection, `Enter` connects/disconnects, `Esc` closes. |
| Bluetooth | Click opens a **dropdown**: toggle adapter, up to 5 devices visible with scroll (paired first), click to pair / connect / disconnect. Icon reflects adapter state; hover tooltip lists connected devices. Keyboard: same as Wi-Fi. |
| Battery | UPower percentage + state icon (charging/discharging sets, same glyphs as the waybar config); hover tooltip shows time remaining. |
| Power | Click opens **Lock / Log Out / Reboot / Power Off**. Keyboard: `Tab`/arrows or the wlogout letters (`s`/`r`/`u`/`l`/`h`/`o`), `Enter` runs the action, `Esc` closes. |
| Lock screen | The `SUPER+L` bind, hypridle, or the power menu locks the session behind a blurred current wallpaper: big 12h clock + date, invisible password field with small breathing dots (typed chars only — `Esc`/`Ctrl+U`/`Ctrl+Backspace` clear, `Enter` submits to PAM), an animated gradient border on verify/fail with a small "Authentication failed" message, a "Caps Lock active" warning, battery, weather and a vol/mic/bt status line (right column), a clickable keyboard-layout switcher, and an MPRIS media card while something plays. Everything is plain text over the blur — no cards, no shadows. Unlocks only on a correct password; no fingerprint (Quickshell PAM is password-only). |
| Wallpaper picker | `SUPER+W` opens a **skwd-wall-style picker** floating over the live desktop: four right-leaning slanted slices per side of a fixed 16:9 center frame, the selected wallpaper enlarged behind an accent border (starts on the current wallpaper; only the focused one shows its filename chip). Scroll / arrow keys / click a slice to preview it centered; click the centered one or press `Enter`/`Space` to apply — `awww` with a random transition, then `matugen` regenerates the whole palette live (requires `[config.wallpaper] set = false` in matugen's config so it never re-applies the image itself). **Type to search**: printable keys filter the set live with a `query · matches` chip above the row, `Backspace` edits, `Esc` clears the search first. `Esc` (with empty search) or clicking bare desktop closes. An optional `dimaround` layer rule (see setup step 4) dims the desktop behind it. Replaces the old rofi `wall-switcher.sh` flow. |

All icons are **Nerd Font glyphs** (JetBrains Mono Nerd Font Propo) using the
same codepoints as `~/.config/waybar/config.jsonc` — battery levels, volume,
mic, wifi and bluetooth icons change with state exactly like waybar's
`format-icons`. Status items have hover tooltips. Popups are layer-shell
"shield" windows that start below the bar (the bar stays clickable while a
popup is open): clicking anywhere outside the panel closes the popup, and
clicking a bar pill toggles it directly. Clicks inside a panel never close it.

## Repo layout

```
shell.qml        entry point (must stay at the repo root — qs -c loads it)
core/Colors.qml  palette singleton — watches matugen's colors.json (regenerated; do not hand-edit)
core/            singletons: Theme, Icons, Popups, Notifs, LockState, ScreenTime
ui/              primitives: NIcon, Pill, Toggle, SignalBars, RoundedImage, TooltipWindow
bar/             the bar + its feedback surfaces: Bar, Workspaces, ClockPill, StatusPill, Osd, Toast
popups/          RicePopup panels: DashPopup (+ CalendarPanel, NotifsPanel, SystemUsage),
                 WifiPopup, BluetoothPopup, PowerPopup, TrayMenuPopup
standalone/      fullscreen session-level surfaces: Wallswitch, Lockscreen
assets/          pfp.png avatar (untracked — drop your own image here)
shaders/         parked Wallswitch shader experiment (not used by live code)
```

## Tweaking — which file controls what

| File | Controls |
|---|---|
| `core/Theme.qml` | **Font family** (`fontFamily`, Rubik), **the single text size** (`textSize`, 14.5 — every non-icon text uses it), icon font (`nerdFont`), the matugen role → bar-color mapping (md3 roles off `Colors`, with fallbacks), metrics (`barHeight`, `pillHeight`, `popupRadius`) |
| `core/Icons.qml` | Nerd Font glyph map (add glyphs here + a `yOffsets` entry if it sits off-center), battery icon sets |
| `shell.qml` | Global shortcuts (`powermenu`, `notification`), palette file path (`FileView`), notification daemon capabilities, toast instantiation |
| `bar/Bar.qml` | Pill layout and popup anchoring |
| `bar/Workspaces.qml` | Minimum slots (`minCount`), idle/active widths, urgent tint |
| `bar/ClockPill.qml` | Bell states, time format, date tooltip |
| `bar/StatusPill.qml` | Tray, volume/mic scroll steps, wifi/bt/battery/power behavior and tooltips |
| `popups/DashPopup.qml` | Dashboard size (`panelWidth`, `panelHeight`) and column layout |
| `popups/CalendarPanel.qml` | Calendar rendering (grid, header, month nav) |
| `popups/NotifsPanel.qml` | Media card, notification rows (hover ✕), empty state, DND + Clear footer |
| `standalone/Wallswitch.qml` | Wallpaper dir, slice geometry (height/width/gap/lean), dim + border, apply command |
| `core/Notifs.qml` | History size cap (30), unread/DND logic, OSD-style handling |
| `bar/Toast.qml` | Toast width, position, per-urgency timings |
| `popups/RicePopup.qml` | Shared popup shell: anchoring/clamping, panel sizes, close behavior, click swallowing |
| `popups/WifiPopup.qml` / `popups/BluetoothPopup.qml` | Per-popup list behavior, password prompt |
| `popups/PowerPopup.qml` | Power actions + commands |
| `standalone/Lockscreen.qml` | Lock-screen widgets/geometry, knobs (`hideInput`, `asteriskDots`, `pamConfig`, `profilePhotoPath`), test overrides; comment out feature blocks here |
| `core/LockState.qml` | The lock switch PowerPopup (or anything) sets to engage the lock |
| `core/Popups.qml` | Which popup is open (exclusivity), outside-click toggle guard |
| `ui/TooltipWindow.qml` / `popups/TrayMenuPopup.qml` | Tooltip rendering / tray menu theming |
| `ui/NIcon.qml` / `ui/Toggle.qml` / `ui/SignalBars.qml` / `ui/Pill.qml` | Primitives: icon sizing, switches, signal bars, pill shape |
