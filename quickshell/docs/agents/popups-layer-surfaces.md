# Popups, layer surfaces & tooltips

Read this before touching anything under `popups/`, `ui/TooltipWindow.qml`,
or the `Popups` singleton — these are the load-bearing rules the shell was
built around.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

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
