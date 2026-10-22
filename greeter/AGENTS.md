# AGENTS.md — agent notes for the greetd greeter

Reference for AI agents / new sessions working on this directory. Read
`quickshell/AGENTS.md` first — the shell-side conventions (palette via matugen,
Nerd Font glyphs, Pill/RicePopup idioms, `console.warn` not `console.log`,
pixel-verify screenshots) all carry over here. This file covers what is
specific to the greeter: the login flow, the wallpaper symlink, and the traps
already paid for.

## What this is

A **greetd greeter** built with Quickshell QML, run by the lightweight **Cage**
kiosk compositor: `greetd.service` → `sh -c 'exec cage -s -d -- quickshell -p /etc/greetd/greeter/shell.qml >/dev/null 2>&1'`.
When login succeeds, quickshell exits; Cage automatically terminates as its
child application closes, and greetd launches the user session (`start-hyprland`).
Cage starts in ~100ms with zero window manager overhead, and stdout/stderr redirection
silences TTY text output. (A minimal `hyprland.lua` is kept in repo as a fallback compositor option).

Live copy is `/etc/greetd/greeter/` — the repo dir is the source; **changes
only take effect on the real greeter after `sudo ./greeter/install.sh`**.
For iteration, preview inside the desktop session:
`quickshell -p greeter/shell.qml` (Greetd socket absent → standalone preview
mode, see gotchas).

## File map

| File | Role |
|---|---|
| `shell.qml` | Entry point. One fullscreen `FloatingWindow` per screen (Cage is an XDG toplevel kiosk and does not implement `wlr-layer-shell`). `//@ pragma UseQApplication` required. |
| `Greeter.qml` | Everything: clock/date, battery, background + luminance sampler, user/password center column, Greetd auth state machine, wallpaper/user/session discovery Processes, state persistence (`/var/cache/greetd/last-user`, `last-session`). |
| `UserSelector.qml` | **Dropdown panel** (not a modal) placed in the center Column between the user pill and the password field. 3 rows visible, scrollable beyond (delegates 14px narrower than the list — scrollbar lane convention). |
| `SessionSelector.qml` | Bottom-left Pill + popup listing wayland/x11 sessions from `/usr/share/{wayland-sessions,xsessions}/*.desktop`. Transparent at rest, blends into wallpaper with adaptive `lockFg`/`lockFgMuted`. |
| `PowerMenu.qml` | Bottom-right Pill + popup: poweroff/reboot/suspend/hibernate via `Quickshell.execDetached(["systemctl", ...])`. Transparent at rest, blends into wallpaper with adaptive `lockFg`. |
| `Theme.qml` | Same matugen role mapping as the bar's Theme (`Colors.md3` via `Colors.qml`) + `userAvatarColor(name)` — deterministic muted HSL per username for the initial-letter avatars. |
| `Colors.qml` | FileView + JsonAdapter of matugen `colors.json`. Preview uses `$HOME/.local/state/quickshell/generated/colors.json`; the real greeter reads `/var/cache/greetd/colors.json` (copied on wallpaper apply). |
| `Icons.qml` / `NIcon.qml` / `Pill.qml` / `RoundedImage.qml` | Same roles as the bar's. `RoundedImage` renders circular avatar photos (`assets/pfp.png` or `~/.face`), falling back to initial-letter circle if missing. `Pill` supports `transparent: true` at rest with animated hover/open tint. |
| `qmldir` | Every component must be listed (singletons + types) — same rule as the bar. |
| `install.sh` | Root install: copies to `/etc/greetd`, makes `/var/cache/greetd` world-writable, sets traversal ACLs (`setfacl -m u:greeter:--x /home/*` and `u:greeter:rX /home/*/Pictures`), adds greeter user to `video` and `input` groups, symlinks initial wallpaper. |
| `save-wallpaper.sh` | One-shot: point `/var/cache/greetd/wallpaper` (atomic symlink swap) to current awww wallpaper. |
| `config.toml` / `hyprland.lua` / `hyprland.conf` | greetd config (Cage command) + fallback compositor configs (`hyprland.lua` uses valid `hl.config({ ... })` API). |
| `assets/` | `wallpaper.jpg` fallback background, `pfp.png` user avatar. |

## Wallpaper: atomic symlink (`/var/cache/greetd/wallpaper`)

The login screen reads `/var/cache/greetd/wallpaper`, which is an atomic symlink pointing directly to the active wallpaper in the user's home (e.g. `/home/<user>/Pictures/wallpapers/...`).
- No image data is copied, preserving disk writes and keeping switches instantaneous.
- **Atomic updates**: `Actions.applyWallpaper` and `Actions.syncGreetdWallpaper()` in `quickshell/core/Actions.qml` update the symlink via `ln -sfn "$WALL" /var/cache/greetd/.wallpaper.tmp && mv -Tf ... /var/cache/greetd/wallpaper`.
- **Permissions**: `install.sh` grants user `greeter` directory traversal permissions on `/home/<user>` (`setfacl -m u:greeter:--x`) and read permissions on `/home/<user>/Pictures` (`setfacl -R -m u:greeter:rX`), enabling `greeter` to read the symlinked target directly without copying.
- **Rendering**: The wallpaper is rendered crisp and unblurred in full native resolution (no full-screen blur `MultiEffect`).
- In preview mode, the greeter resolves `/var/cache/greetd/wallpaper` directly or falls back to `awww query` / `assets/wallpaper.jpg`.

## User Avatar (pfp.png and ~/.face)

The avatar circle in `Greeter.qml` and `UserSelector.qml` displays:
1. Per-user avatar if `~/.face` or `~/.face.icon` exists.
2. Otherwise, `assets/pfp.png` (place your avatar at `greeter/assets/pfp.png`, which installs to `/etc/greetd/greeter/assets/pfp.png`).
3. If no image exists or it fails to load, falls back to the deterministic initial-letter circle with `Theme.userAvatarColor`.

## Auth flow & the "Login Failed" contract (user-specified — do not decorate)

- States: `idle | authenticating | failed | launching`. `authenticating` is
  internal only (blocks double-submit) — there is no "Verifying" UI. On
  failure the buffer is cleared and the field shows plain red **"Login
  Failed"** — the ONLY feedback. No gradient ring, no fade animation, no
  auto-reset timer (all removed 2026-10-08 at the user's request). The
  failed state clears the moment the user types again (`handleKey` resets
  `authState` on the first printable key) or presses Esc; a new attempt is
  then typed normally.
- PAM errors etc. go to `console.warn` only, never on screen.
- `startAuth(user)` cancels any live session and `createSession`s the picked
  user; `submit()` responds when Authenticating, or parks the password in
  `pendingPassword` and answers the first `authMessage` (greetd races).
- After a failure, `retryTimer` re-creates the session after 1s so the next
  password works without re-selecting the user.
- On `readyToLaunch`: persist last-user/last-session, then
  `Greetd.launch(cmdList, env, true)`. Session exec strings are split on
  whitespace; env gets `XDG_SESSION_TYPE` (+ Hyprland desktop vars for
  wayland Hyprland sessions).

## Popup conventions

- **Bounding Box Sizing**: `SessionSelector` and `PowerMenu` dynamically expand
  their `width` and `height` to encompass the popup panel when open (`height: open ? pill.height + 10 + popup.height : pill.height`).
  If an Item's bounds don't enclose its popups, Qt Quick's `contains()` returns
  false for clicks outside the trigger pill, and the root-level outside-click
  dismisser (`z: 40`) swallows the click and immediately closes the popup!
- The center column (`z: 50`) sits ABOVE the outside-click dismisser
  (`z: 40`), which is enabled only while any popup is open — so the user
  pill and open dropdown keep their clicks.
- Opening any popup (user dropdown, session, power) closes the other two —
  wired via each component's `onOpenChanged`. Keep that exclusivity when
  adding popups.
- Esc closes popups first; only with none open does it clear the password
  buffer.
- The user dropdown lives **inside the center Column** (not an overlay), so
  the password field shifts down only while it's open — matches the
  reference mockup; don't move it to a centered modal. It has no solid background
  and blends into the wallpaper with adaptive contrast.
- **Touchpad Tap-to-Click**: Because Cage kiosk does not map touchpad tap gestures to mouse button events by default, all clickable controls (`Pill`, `SessionSelector` / `PowerMenu` / `UserSelector` delegates, submit button, and root dismisser) use Qt Quick `TapHandler` alongside `MouseArea` to ensure single-finger tap gestures fire reliably.
- **Frosted Button & Popup Styling**: Buttons and popups use frosted glass styling (`Qt.rgba(1, 1, 1, 0.08)` / `Qt.rgba(0, 0, 0, 0.40)` with `Qt.rgba(1, 1, 1, 0.18)` borders) rather than opaque theme palette colors.

## Gotchas

- **Standalone preview mode**: without the greetd socket `Greetd.available`
  is false; the greeter still renders and `submit()` simulates a failure
  after 700ms via `testTimer`. Never treat preview auth as real.
- Caps Lock is tracked by toggling on the CapsLock key event (no
  `hyprctl devices` polling here, unlike the lockscreen — greeter compositor
  has one keyboard).
- The luminance sampler (16×9 Canvas → `wallDark`) drives `lockFg`/
  `lockFgMuted`; retry/coverage rules are the same as the lockscreen's
  (all-transparent sample = retry, 5 cap, fall back dark).
- Battery comes from `UPower.displayDevice` (~3s to populate — screenshot
  verification needs a wait); percentage is 0–1. Icon = same Nerd Font
  `batteryGlyph` set as the bar — keep them in sync.
- Test harness pattern: a throwaway `/tmp/*.qml` PanelWindow that imports
  this dir via `file:` URL and drives `Greeter`'s public properties
  (`users`, `userMenuOpen` alias, `authState`, `buffer`) on Timers. Don't
  add test files to the repo, and kill the instance when done (check
  `pgrep -ax qs` — the real bar is `qs -c rice`).
- `hyprctl dispatch 'hl.dsp.exit()'` (descriptor form) is required in the
  compositor autostart — plain `dispatch exit` dies in the Lua parser, same
  trap as the bar's GlobalShortcuts.
- Every QML file here must be in `qmldir`; QML property names cannot start
  uppercase; `console.log` doesn't surface — use `console.warn`.

## User preferences that applied here

- Verification is manual — the user checks the real greeter themselves;
  agents verify via throwaway-instance screenshots only.
- No gradients/animations for error states; plain text feedback.
- Scrollable lists keep the 14px scrollbar lane; pills/popups reuse
  `Pill`/Theme tokens rather than ad-hoc styling.
- The clock matches the lockscreen: `y = height * 0.10`, time/AMPM 75px.
- Long passwords: dots match `quickshell/standalone/Lockscreen.qml` with 10px diameter, `spacing: 3`, `lockFgMuted` at 0.9 opacity, in a clipped horizontal Flickable that leaves a reserved lane for the submit arrow. Note: manual horizontal scrolling / flicking on the dots does not work reliably in this layer-shell environment; documented per user instruction — do not attempt to fix.
- **Wallpaper Blur**: Wallpaper uses the exact same `MultiEffect` blur as `Lockscreen.qml` (`blurMax: 64`, `blur: 1.0`, `anchors.margins: -64`) over the full-resolution image without downsampling.
- **Qt Platform (`QT_QPA_PLATFORM=wayland`)**: Running quickshell on a TTY or kiosk without setting `QT_QPA_PLATFORM=wayland` causes Qt to look for an X11 display and fail with `Could not load the Qt platform plugin "xcb" in "" even though it was found`. Greetd's `config.toml` must explicitly export `QT_QPA_PLATFORM=wayland`.
- **Compositor and Tap-to-Click**: Cage is a barebones kiosk compositor that does not configure libinput tap-to-click (physical clicks work, but tap gestures are ignored by libinput). For full touchpad tap-to-click support, `hyprland.lua` and `hyprland.conf` include `touchpad { tap_to_click = true }`.
