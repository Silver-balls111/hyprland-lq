# AGENTS.md — agent notes for the greetd greeter

Reference for AI agents / new sessions working on this directory. Read
`quickshell/AGENTS.md` first — the shell-side conventions (palette via matugen,
Nerd Font glyphs, Pill/RicePopup idioms, `console.warn` not `console.log`,
pixel-verify screenshots) all carry over here. This file covers what is
specific to the greeter: the login flow, the wallpaper symlink, and the traps
already paid for.

## What this is

A **greetd greeter** built with Quickshell QML, run by a minimal Hyprland
compositor instance: `greetd.service` → `start-hyprland -- -c
/etc/greetd/hyprland.lua` → `quickshell -p /etc/greetd/greeter/shell.qml`.
When login succeeds, quickshell exits; the compositor's autostart then runs
`hyprctl dispatch 'hl.dsp.exit()'` and greetd starts the user session.

Live copy is `/etc/greetd/greeter/` — the repo dir is the source; **changes
only take effect on the real greeter after `sudo ./greeter/install.sh`**.
For iteration, preview inside the desktop session:
`quickshell -p greeter/shell.qml` (Greetd socket absent → standalone preview
mode, see gotchas).

## File map

| File | Role |
|---|---|
| `shell.qml` | Entry point. One fullscreen Overlay `PanelWindow` per screen, `Exclusive` keyboard focus, namespace `quickshell:greeter`. `//@ pragma UseQApplication` required. |
| `Greeter.qml` | Everything: clock/date, battery, background + luminance sampler, user/password center column, Greetd auth state machine, wallpaper/user/session discovery Processes, state persistence (`/var/cache/greetd/last-user`, `last-session`). |
| `UserSelector.qml` | **Dropdown panel** (not a modal) placed in the center Column between the user pill and the password field. 3 rows visible, scrollable beyond (delegates 14px narrower than the list — scrollbar lane convention). |
| `SessionSelector.qml` | Bottom-left Pill + popup listing wayland/x11 sessions from `/usr/share/{wayland-sessions,xsessions}/*.desktop`. |
| `PowerMenu.qml` | Bottom-right Pill + popup: poweroff/reboot/suspend/hibernate via `Quickshell.execDetached(["systemctl", ...])`. |
| `Theme.qml` | Same matugen role mapping as the bar's Theme (`Colors.md3` via `Colors.qml`) + `userAvatarColor(name)` — deterministic muted HSL per username for the initial-letter avatars. |
| `Colors.qml` | FileView + JsonAdapter of matugen `colors.json`. Preview uses `$HOME/.local/state/quickshell/generated/colors.json`; the real greeter reads `/var/cache/greetd/colors.json` (copied on wallpaper apply). |
| `Icons.qml` / `NIcon.qml` / `Pill.qml` / `RoundedImage.qml` | Same roles as the bar's. `RoundedImage` is currently unused (initial-letter avatars replaced photo avatars 2026-10-08) but stays as a primitive; it is still in `qmldir`. |
| `qmldir` | Every component must be listed (singletons + types) — same rule as the bar. |
| `install.sh` | Root install: copies to `/etc/greetd`, makes `/var/cache/greetd` world-writable, **grants greeter-user ACLs for the wallpaper symlink**, removes legacy copy-flow artifacts. |
| `save-wallpaper.sh` | One-shot: point `/var/cache/greetd/wallpaper` at the current awww wallpaper. |
| `config.toml` / `hyprland.lua` / `hyprland.conf` | greetd config + the minimal compositor configs (Lua is the live one per config.toml; the .conf is the legacy syntax twin). |
| `assets/` | `wallpaper.jpg` fallback background, `pfp.png` legacy avatar. |

## Wallpaper: symlink, never copy (2026-10-08 rewrite)

The old flow copied the wallpaper image to `/var/cache/greetd/wallpaper.png`
on every change — wasteful and stale-prone. Current flow:

- The **user session** (bar) owns the link: `Actions.applyWallpaper` in
  `quickshell/core/Actions.qml` and `Actions.syncGreetdWallpaper()` (called
  from PowerPopup before power actions) re-point
  `/var/cache/greetd/wallpaper` at the awww wallpaper with an **atomic swap**:
  `ln -sfn "$1" /var/cache/greetd/.wallpaper.tmp && mv -Tf ... wallpaper`.
  Build-then-rename, so the greeter never observes a half-written link.
  The same apply also copies matugen's `colors.json` to
  `/var/cache/greetd/colors.json` so popup/pill colors match the bar.
  The same apply also copies matugen's `colors.json` to
  `/var/cache/greetd/colors.json` so popup/pill colors match the bar.
- The **greeter** resolves, in order: the symlink → legacy
  `wallpaper-path` file → `/tmp/greetd-wallpaper.png` → bundled
  `assets/wallpaper.jpg`. `[ -f symlink ]` follows the link, so a dangling
  link falls through to fallbacks.
- Permissions are the whole trick: `/home/<user>` is `0700`, and the greeter
  runs as user `greeter` — it can't traverse into the home to read the
  target. `install.sh` grants `u:greeter:--x` on each `/home/*` (traverse
  only, no listing) and `rX` + default ACLs on `~/Pictures/wallpapers` so
  future wallpapers stay readable. Hardlinks were rejected: `/var/cache` and
  `/home` are different filesystems here.
- If the greeter ever shows the fallback wallpaper on a real boot, check
  `sudo -u greeter cat /var/cache/greetd/wallpaper` and the ACLs
  (`getfacl /home/<user>`), not the QML.

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
- Users with real avatars (`.face` files) exist in the model but avatars are
  NOT displayed anymore — initial-letter circles only.

## Popup conventions

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
  reference mockup; don't move it to a centered modal.

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
- Long passwords: dots live in a clipped horizontal Flickable that leaves
  a reserved lane for the submit arrow and auto-scrolls to the newest dot.
