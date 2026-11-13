# Greetd greeter companion

Read this before touching anything under `greeter/` or the greetd
installation flow.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

## Greetd Greeter companion (`greeter/`)

The repository includes a companion greetd greeter (`greeter/`) designed to mirror the bar's styling and lockscreen aesthetic. Key architectural invariants connecting quickshell to the greeter:
- **Compositor & Window Type**: The greeter runs under the lightweight `cage` kiosk compositor (`greetd.service` → `sh -c 'exec cage -s -d -- quickshell -p /etc/greetd/greeter/shell.qml >/dev/null 2>&1'`). Because Cage is a strict XDG toplevel kiosk compositor and does **not** support `zwlr_layer_shell_v1`, `greeter/shell.qml` uses `FloatingWindow { fullscreen: true }`, NOT `PanelWindow`.
- **Silent & Fast Boot**: Directing cage + quickshell stdout/stderr to `/dev/null` silences compositor and Mesa/EGL text spam on TTY 1 during boot and session handoff.
- **Shared Luminance Sampler & Transparent UI**: Like `Lockscreen.qml`, `greeter/Greeter.qml` uses a 16×9 offscreen Canvas to compute Rec.709 luma (`wallDark`) and dynamically set `lockFg` / `lockFgMuted`. The wallpaper uses the identical blur stack as `Lockscreen.qml` (`blurMax: 64`, `blur: 1.0`, `anchors.margins: -64`) plus the same `sourceSize` decode downsample — without the downsample the nativewide decode aliases into the window and the blur reads as an oil-painting smear. Password dots use the identical 10px size and `spacing: 3` gap as `Lockscreen.qml`. Bottom pills (SessionSelector, PowerMenu) and the user selection pill are transparent at rest and blend cleanly into the background with frosted glass popups. All interactive controls use `TapHandler` alongside `MouseArea`.
- **Wallpaper Sync**: The desktop shell updates the greeter wallpaper via an atomic symlink swap (`ln -sfn "$WALL" /var/cache/greetd/.wallpaper.tmp && mv -Tf ... /var/cache/greetd/wallpaper`), so no disk space is duplicated and the update is instant. In `quickshell/core/Actions.qml`, `applyWallpaper` and `syncGreetdWallpaper()` perform this symlink swap and sync `colors.json`. `greeter/install.sh` ensures directory traversal ACLs (`setfacl -m u:greeter:--x /home/*` and `u:greeter:rX /home/*/Pictures`).
- **Password Dots Limitation**: In the greeter's clipped horizontal Flickable, password dots do not support manual mouse dragging/scrolling (layer/kiosk surface grab limitation). Documented by requirement — do not attempt to fix.
- **Keyring unlock at login**: `greeter/pam.d/greetd` (installed by `install.sh` to `/etc/pam.d/greetd`, original at `greetd.pambackup`) adds `pam_gnome_keyring.so` (`auth optional` + `session optional auto_start`) so the login keyring unlocks with the password typed at the greeter. Auto-unlock targets the keyring literally named `login` — it must be the default keyring with password = login password. `install.sh` also appends `password optional pam_gnome_keyring.so` to `/etc/pam.d/passwd` so the keyring password follows login-password changes. Do not stack the module into `system-login` too — the greetd stack already includes it (double instances break the unlock).
- **Live Deployment**: The live greeter lives in `/etc/greetd/greeter/`. Editing files in `greeter/` does not affect the live system until the user runs `sudo ./greeter/install.sh`.
