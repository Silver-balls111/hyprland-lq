# quickshell_rice

A floating pink pill bar for **Arch Linux + Hyprland ≥ 0.56**, built for **Quickshell 0.3.1**.
Design: workspace pills (left) · clock + bell (center) · status pill (right).

> Hyprland 0.56 replaced the IPC dispatch syntax with Lua (`hl.dsp.*`). This bar
> sends the new syntax and falls back to the old one on Hyprland < 0.56
> (auto-detected via `hyprctl version` at startup).

## Run

```sh
qs -p ~/Documents/Dev/quickshell_rice/shell.qml
```

Or register it as a named config:

```sh
mkdir -p ~/.config/quickshell
ln -s ~/Documents/Dev/quickshell_rice ~/.config/quickshell/rice
qs -c rice
```

Autostart with Hyprland — add to `~/.config/hypr/hyprland.conf`:

```ini
exec-once = qs -c rice        # or: qs -p ~/Documents/Dev/quickshell_rice/shell.qml
```

## Features

| Element | Behavior |
|---|---|
| Workspaces (1–5+) | Click to switch. Always shows at least 5 slots (extra empty slots create the workspace on click); more appear if you use more. The active workspace's pill widens with the pink fill; a workspace with a window requesting attention is tinted orange until visited. |
| Clock pill | Hover (or click) opens a **calendar** — always opens on the current month, navigate with the chevrons. Closes when the mouse leaves the popup, on outside click, or `Esc`. |
| System tray | Real StatusNotifier tray with menus (right-click), primary action (left-click) and scroll actions. |
| Volume | Scroll = ±1%, click = mute/unmute. Mirrors wpctl state. |
| Mic | Scroll = ±2%, click = mute/unmute. |
| Wi-Fi | Click opens a **dropdown**: toggle Wi-Fi, up to 5 networks visible with scroll, sorted by signal (connected first). Click to connect — secured networks ask for a password inline. Hover tooltip shows SSID + signal. |
| Bluetooth | Click opens a **dropdown**: toggle adapter, up to 5 devices visible with scroll (paired first), click to pair / connect / disconnect. Icon reflects adapter state; hover tooltip lists connected devices. |
| Battery | UPower percentage + state icon (charging/discharging sets, same glyphs as the waybar config); hover tooltip shows time remaining. |
| Power | Click opens **Lock / Log Out / Reboot / Power Off**. |

All icons are **Nerd Font glyphs** (JetBrains Mono Nerd Font Propo) using the
same codepoints as `~/.config/waybar/config.jsonc` — battery levels, volume,
mic, wifi and bluetooth icons change with state exactly like waybar's
`format-icons`. Status items have hover tooltips. Popups are layer-shell
"shield" windows that start below the bar (the bar stays clickable while a
popup is open): clicking anywhere outside the panel closes the popup, and
clicking a bar pill toggles it directly.

## Tweaks

- Colors, font, sizes → `Theme.qml`
- Icon set (Canvas-drawn, no fonts needed) → `Icons.qml`
- Minimum workspace slots → `minCount` in `Workspaces.qml`
- Calendar hover open/close delays → `openTimer` / `closeTimer` in `ClockPill.qml`
- Power menu commands → `PowerPopup.qml`

All icon glyphs live in `Icons.qml` (Nerd Font codepoints, rendered as text —
no Canvas or icon theme involved). Colors → `Theme.qml`; minimum workspace
slots → `minCount` in `Workspaces.qml`; calendar hover delays → `ClockPill.qml`;
power menu commands → `PowerPopup.qml`.
