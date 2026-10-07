# developers.md — guide for human developers

Architecture, conventions and workflows for working on this repo. Assumes QML
knowledge; explains everything Quickshell/Hyprland-specific. For accumulated
debugging history and hard-won gotchas, read [AGENTS.md](AGENTS.md) (it is the
residue of real debugging sessions — this file is the stable map). Performance
work has its own plan in [OPTIMIZATIONS.md](OPTIMIZATIONS.md).

## What this is

A Quickshell **0.3.1** desktop shell for **Arch Linux + Hyprland ≥ 0.56**,
run as the named config **`rice`** (`qs -c rice`; `~/.config/quickshell/rice`
is a symlink to this repo). One QML codebase replaces waybar (bar), swaync
(notifications + dashboard), hyprlock (lock screen), wlogout (power menu) and
three rofi pickers (wallpaper, clipboard, tray menus). Colors are never
hardcoded — matugen regenerates the palette from the wallpaper and the shell
recolors live.

Hyprland 0.56 replaced its IPC dispatch syntax with **Lua** (`hl.dsp.*`); this
shell speaks the new syntax and falls back on older Hyprland (detected via
`hyprctl version` at startup).

## Requirements

| Package | Why |
|---|---|
| `quickshell` 0.3.1 | The shell runtime (`qs`) |
| `hyprland` ≥ 0.56 | WM (Lua config) |
| `ttf-jetbrains-mono-nerd` | Icon glyphs (Nerd Font Propo) |
| `ttf-rubik-vf` | All text |
| `matugen` + `awww` | Palette generation / wallpaper transitions |
| `networkmanager`, `upower`, `pipewire` + `wireplumber`, `bluez` | Wi-Fi, battery, volume/mic, bluetooth modules |
| `cliphist` + `wl-clipboard` | Clipboard history backend |

## Run & dev loop

```sh
qs -c rice                 # named config (hot-reloads on every file save)
qs -p shell.qml            # direct path — identical result
```

- Logs go to stderr and `/run/user/1000/quickshell/by-id/<id>/log.qslog`.
  **`console.warn` surfaces, `console.log` does not** — use `warn` everywhere.
- After QML edits a window can map but paint *nothing* (wallpaper shows
  through, zero log errors): stale `~/.cache/quickshell` and/or
  `/run/user/1000/quickshell/vfs` — `rm -rf` both and relaunch.
- Before debugging a "frozen" bar, check it is alive: `pgrep -x qs` and
  `hyprctl layers`. A dead instance's old log still exists and greps "fine".

## Repo layout

`shell.qml` **must** stay at the repo root — it is what `qs -c <name>` loads.
Everything else is grouped by role; each directory carries its own `qmldir`.

```
shell.qml            Entry: GlobalShortcuts, NotificationServer, palette FileView,
                     Toast/Osd, per-screen Bar (Variants), Wallswitch, Clipboard, Lockscreen
core/Colors.qml      palette singleton — FileView-watches matugen's colors.json (regenerated, do not hand-edit)
core/                Singletons: Theme, Icons, Popups, Notifs, LockState, ScreenTime
ui/                  Reusable primitives: NIcon, Pill, Toggle, SignalBars, RoundedImage, TooltipWindow
bar/                 The bar and its feedback surfaces: Bar, Workspaces, ClockPill, StatusPill, Osd, Toast
popups/              RicePopup-based anchored panels: DashPopup (+ CalendarPanel, NotifsPanel,
                     SystemUsage), WifiPopup, BluetoothPopup, PowerPopup, TrayMenuPopup, ClipboardPopup
standalone/          Fullscreen session-level surfaces: Wallswitch, Lockscreen
assets/              pfp.png avatar (untracked — drop your own image there)
shaders/             Parked Wallswitch AA-shader experiment (NOT used by live code; kept for a future retry)
```

QML import rules in force:

- Same-directory types resolve implicitly (plus that dir's `qmldir` for
  singletons — `core/` declares its six there).
- Cross-directory types need an explicit relative import (`import "../core"`),
  added at the top of every file that uses them.
- `assets/` is referenced repo-root-relative from QML files one level deep:
  `Qt.resolvedUrl("../assets/pfp.png")` — the URL resolves against the *file's*
  location, so the `../` matters.

## Architecture

### Boot chain (shell.qml)

`Component.onCompleted: ScreenTime.init()` → the four `GlobalShortcut`s
(`qs-bar:powermenu`, `qs-bar:notification`, `qs:wallpaper-switcher`,
`qs:clipboard`) → the `NotificationServer` (this shell **is** the notification
daemon; exactly one instance, at shell root, never per-screen) → the palette
`FileView` → `Toast`, `Osd` → `Variants { model: Quickshell.screens }` spawning
one `Bar` per screen → `Wallswitch`, `ClipboardPopup`, `Lockscreen` (declared
after `Variants` so their invisible input shields stack above the bar).

### Theming

matugen renders `colors.json` (`[templates.quickshell]` in
`~/.config/matugen/config.toml` → `~/.local/state/quickshell/generated/`);
`core/Colors.qml` (singleton, FileView + JsonAdapter) watches it live, and
`core/Theme.qml` maps its md3 roles onto the UI palette — every color binding
in the tree follows. Derived tones (fgMuted, track, divider, …) stay formulaic on top
of the matugen roles. Fonts: Rubik for all text, JetBrains Mono Nerd Font Propo
for glyphs, one `Theme.textSize` (14.5), **no `font.weight` anywhere**.

Matugen 4.2 traps: the `[config.wallpaper]` block must exist even with
`set = false` (removing it or its `command`/`arguments` aborts every matugen
run), and with `set = false` matugen never re-applies the wallpaper itself.

### Popup architecture (deliberate — do not "simplify")

`PopupWindow`/xdg popups from a layer-shell bar are broken in Quickshell 0.3.1
(grab failures, swallowed clicks). All popups are therefore **full-screen
transparent layer-shell shields** (`RicePopup` base) with the visible panel
positioned inside at `y: Theme.barHeight`; clicking the bar again lands inside
the shield and closes the popup. Invariants:

- `Popups` (singleton) holds `active` — the single source of truth for which
  popup is open; opening one closes the others, re-clicking the trigger
  toggles. `lastDismiss` guards against the closing outside-click re-triggering.
- Every popup's body declares a full-size "swallower" `MouseArea` *before* the
  content alias, so clicks on empty/disabled areas never fall through.
- Scrollable lists keep delegates `width: list.width - 14` so the attached
  ScrollBar never overlays content.
- Each layer window sets a `WlrLayershell.namespace` (`quickshell:bar`,
  `quickshell:popup`, `quickshell:toast`, `quickshell:tooltip`,
  `quickshell:wallswitch`, `quickshell:clipboard`, `quickshell:lockscreen-test`
  in the lock test branch) — Hyprland layerrules (blur, dimaround) match on
  these strings.
- `RicePopup` subclasses override `onVisibleChanged` via
  `Connections { target: root; function onVisibleChanged() {...} }` — a
  subclass handler would shadow the base class's and silently break
  close/focus bookkeeping.
- Hover-out auto-close does not exist on purpose (it fired when the shield
  mapped under the cursor).

### Singletons (core/)

| Singleton | Owns |
|---|---|
| `Theme` | Fonts, `textSize`, metrics, palette role mapping (md3 roles off `Colors`) |
| `Icons` | Nerd-font codepoint map, `batteryGlyph()`, per-glyph `yOffset()` |
| `Popups` | Which popup is open (exclusivity), dismiss guard |
| `Notifs` | Notification history (capped 30), unread/DND state, toast routing |
| `LockState` | `engaged` bool bridging any caller to `Lockscreen.engage()` |
| `ScreenTime` | All-day screen-time accumulator (idle via `IdleMonitor`, persisted to `~/.cache/quickshell_rice/screen-time`) |

**Singletons are lazy**: a pragma-Singleton component does nothing until first
accessed. That is why `shell.qml` touches `ScreenTime.init()` explicitly — it
must accumulate even if the dashboard is never opened.

### Services & their quirks (verified on 0.3.1)

- `Pipewire`, `Networking`, `UPower`, `SystemTray`, `Mpris`, `Bluetooth` are
  **singletons** — never instantiate them. `NotificationServer` is the one
  service you DO instantiate — exactly once, at shell root (the process that
  owns `org.freedesktop.Notifications` wins the DBus name; a second instance
  anywhere means a name fight). Volume only binds with a
  `PwObjectTracker { objects: [...] }` present.
- UPower populates ~3 s after launch — gate on `displayDevice.ready`;
  `percentage` is 0–1 (×100).
- `Mpris.players` is an ObjectModel — iterate `.values`; `trackArtists` is a
  single string despite the plural name.
- `Notification` wrappers need `tracked = true` set in `onNotification` or
  they are destroyed when the handler returns (later `expire()` throws).
- Quickshell 0.3.1 has **no CPU/RAM/temp/disk API** — `SystemUsage` and
  `ScreenTime` poll `/proc`, `/sys` and `df` with `FileView` + Timer +
  `reload()` (procfs emits no inotify events; `watchChanges` is useless there).
- Repo convention for processes: `command: [...]` + `running = true`, not
  `Process.exec()`.

### Keyboard navigation convention

Anchored popups: a `selIndex` property + `Keys.onPressed` routing —
`Tab`/`Down` next, `Backtab`/`Up` prev (wrapping), `Home`/`End` ends,
`Enter`/`Space` activates, lists scroll via `positionViewAtIndex(selIndex,
Contain)`. `RicePopup.keyNavEnabled: true` enables keyboard nav; the power
popup additionally sets `grabKeys: true` to grab exclusive keyboard while
open. `TrayMenuPopup` is a standalone PanelWindow and sets `Exclusive` + its
own body `Keys` itself. The dashboard intentionally has no keyboard nav.

## Conventions for new code

1. **Every component is listed in its directory's `qmldir`** (singletons with
   the `singleton` keyword). A missing entry = type not resolvable from other
   dirs.
2. Cross-references between directories always use explicit relative imports.
3. All non-icon text uses `Theme.textSize`; all icons go through `NIcon` +
   `Icons`. New glyphs must be render-tested (a codepoint in the cmap can
   still render as tofu — see AGENTS.md "Font coverage lies").
4. Any new scrollable list reserves the 14 px scrollbar lane.
5. Any new pill exposes anchor properties (`rowX`/`*RightX`) if popups will
   anchor to it — a NaN anchor makes a popup open invisibly.
6. Never use `QsWindow.mask` (stale geometry → click-through bar) and never
   `MultiEffect.maskSource` in layer-shell windows (renders nothing —
   `RoundedImage` is a Canvas-drawn clip for this reason).
7. Property names cannot start with an uppercase letter; a bad binding fails
   *silently* to a wrong value — when something renders wrong, `console.warn`
   the value before trusting the item tree.
8. `Column`/`Row` skip invisible children — reserve hover-only slots with
   `opacity`/`enabled`, not `visible`.

## Common tasks

**Add a glyph**: pick the codepoint from the font's own cmap
(`fontTools.TTFont.getBestCmap()` on the Nerd Font), add it to `Icons.qml`
with a `yOffset` if it sits off-center, render-test with a throwaway strip
window + `grim`, then commit.

**Add a popup**: subclass `RicePopup` in `popups/`, set `popupName`, list it
in `popups/qmldir`, instantiate it in `Bar.qml` (anchored popups) or
`shell.qml` (standalone tools), add a `Popups.toggle("name")` trigger
(GlobalShortcut in `shell.qml` under appid `qs-bar` for bar features, `qs`
for desktop tools), and follow the swallower/scrollbar/Connections rules
above.

**Add a bar pill**: implement against `Pill` in `bar/`, fix its width,
expose anchor properties, wire tooltips through `Bar.showTooltip()`.

**Recolor**: nothing to do in QML — matugen drives everything. To change the
*role mapping* (which matugen role feeds which UI color), edit the role
bindings at the top of `core/Theme.qml`.

## Hyprland integration

- Global shortcuts: appid `qs-bar` (powermenu, notification, lock) and `qs`
  (wallpaper-switcher, clipboard). Bound in the user's Lua config, e.g.
  `hl.bind(mainMod .. " + X", hl.dsp.global("qs-bar:powermenu"))`.
  `IpcHandler` does not exist in 0.3.1 — GlobalShortcut is the only entry
  point.
- Scripts cannot use `hyprctl dispatch global` (Lua parser rejects it) — the
  **dispatch** request with the descriptor works:
  `hyprctl dispatch 'hl.dsp.global("qs:lock")'` — `eval` returns "ok" but
  DISCARDS the descriptor and never triggers (verified via popup test).
  That is what hypridle's `lock_cmd` uses.
- The user's config is Lua; any dispatch strings generated for them must be
  valid Lua (`hl.dsp.*`).
- PowerPopup is the wlogout replacement: its commands/letter keybinds mirror
  `~/.config/wlogout/layout` (kept only as reference). `IpcHandler` does not
  exist in Quickshell 0.3.1 — GlobalShortcut is the only bind entry point.

## Testing & verification

- **Verification of interactions is manual** — never script mouse/keyboard
  input (ydotool is off-limits unless asked).
- Screenshots: `hyprshot -m output -m eDP-1 --raw > out.png` (exits 1 even on
  success) or, for fixed regions of known coordinates, `grim -g "X,Y WxH"`.
  Verify renders by pixel-scanning (magick/PIL), not by eyeballing thumbnails.
- **Throwaway-instance pattern** (layout tests without clicking the bar): run
  a second `qs -p /tmp/test.qml` that imports the repo *subdirectories* via
  `file:` URLs — bare absolute paths are rejected:

  ```qml
  import "file:/home/anuj/Documents/Dev/quickshell_rice/core"
  import "file:/home/anuj/Documents/Dev/quickshell_rice/popups"

  ShellRoot {
      DashPopup {}
      Component.onCompleted: Popups.active = "clock"
  }
  ```

  (Quickshell's log may WARN that it "cannot resolve" the `file:` imports for
  its file watcher — the QML engine resolves them fine; the config loads.)
  Throwaways must not instantiate a `NotificationServer` (name collision with
  the real instance); two instances coexist otherwise. **Kill throwaways when
  done** — a stray once pixel-overlapped the real bar for a day.
- Lock screen preview: never trigger the real lock from scripts (a kill
  mid-lock bricks the session; recovery = TTY + `loginctl unlock-session`).
  Use `Lockscreen { testMode: true }` in a throwaway — same content in an
  overlay window, Enter simulates a wrong password, no PAM.
- If a newer Quickshell lands in Arch `extra` (>0.3.1), re-verify the config
  before assuming anything still works.
