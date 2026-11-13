# Quickshell Greetd Login Screen

A customized, themeable login greeter for **greetd** built with **Quickshell** (QML) and styled to seamlessly match your Hyprland desktop rice.

## Features

- **Wallpaper Synchronization:**
  - Automatically queries and displays your active session's wallpaper using `awww`.
  - Every wallpaper change re-points the symlink `/var/cache/greetd/wallpaper` at the current wallpaper (atomic `ln` + `mv` swap) — no image is ever copied, so the login screen always shows the live system wallpaper.
  - `install.sh` grants the `greeter` user a traverse-only ACL on `/home/<user>` plus read access to `~/Pictures/wallpapers`, since the greeter reads the wallpaper in place through the symlink.
  - Dynamically calculates average wallpaper luminance via a sampler to ensure crystal-clear text contrast on light or dark wallpapers.
  - Applies a smooth 64px background blur (with a bounded source-size decode, matching the lockscreen's blur stack).
- **Clock & Battery:**
  - Large centered 12-hour clock (`hh:mm AM/PM`) and date label matching the rice lockscreen design.
  - Top-right live battery indicator with percentage and stateful charging/discharging Nerd Font icon (via UPower).
- **User & Authentication:**
  - Remembers the last logged-in user and presents their password field on boot.
  - Initial-letter avatar (deterministic muted color per username) and username pill.
  - Scrollable user dropdown below the username pill for switching between any detected system user accounts.
  - On a failed login the password field is cleared and shows plain **"Login Failed"** feedback — typing starts the next attempt immediately (no gradient rings or animations).
  - Caps Lock warning indicator.
  - Direct integration with `Quickshell.Services.Greetd` for authentication; the whole auth state machine lives in `GreeterState.qml` (one per system, shared across monitors) while `Greeter.qml` is UI only.
- **Session Selector (Bottom-Left):**
  - Scans `/usr/share/wayland-sessions/` and `/usr/share/xsessions/` dynamically for desktop environments (Hyprland, Hyprland uwsm, etc.).
  - Remembers your last chosen session in `/var/cache/greetd/last-session`.
- **Power Menu (Bottom-Right):**
  - Instant access to Power Off, Reboot, Suspend, and Hibernate actions via `systemctl`.
- **Preview & Test Mode:**
  - Can be tested and previewed live inside your Hyprland desktop session without logging out or rebooting:
    ```bash
    quickshell -p greeter/shell.qml
    ```

---

## Directory Structure

```
greeter/
├── shell.qml             # Quickshell root window entry point
├── Greeter.qml           # Main login interface (UI only — binds to GreeterState)
├── GreeterState.qml      # Singleton: wallpaper/user/session discovery + Greetd auth state machine
├── SessionSelector.qml   # Bottom-left session picker popup
├── PowerMenu.qml         # Bottom-right power actions popup
├── UserSelector.qml      # Scrollable dropdown user account picker
├── Theme.qml             # MD3 palette & typography tokens
├── Colors.qml            # matugen colors.json loader (preview $HOME / real /var/cache/greetd)
├── Icons.qml             # Nerd Font glyph maps & vertical corrections
├── NIcon.qml             # Fixed-square Nerd Font icon renderer
├── Pill.qml              # Reusable rounded interactive pill component
├── RoundedImage.qml      # Canvas-clipped circular image (reusable primitive)
├── qmldir                # QML module export definitions
├── hyprland.conf         # Fallback greeter compositor configuration (native Hyprland)
├── hyprland.lua          # Fallback greeter compositor configuration (Hyprland Lua)
├── config.toml           # /etc/greetd/config.toml configuration (Cage kiosk)
├── save-wallpaper.sh     # Utility script to query awww and save wallpaper
├── install.sh            # One-step installation script
└── assets/
    ├── pfp.png           # Fallback user avatar
    └── wallpaper.jpg     # Fallback rice wallpaper
```

---

## How It Works

1. **Greeter Launch Chain:**
   `systemd` → `greetd.service` → `sh -c 'exec cage -s -d -- quickshell -p /etc/greetd/greeter/shell.qml'` (see `config.toml`).
   The greeter runs under the lightweight **Cage** kiosk compositor (it starts in ~100ms and supports no layer shell, hence the fullscreen `FloatingWindow` in `shell.qml`). `hyprland.conf` / `hyprland.lua` are kept as fallback compositor options.
2. **Login & Session Handoff:**
   - Once credentials are verified, `Greetd.launch(command, environment, true)` is called with your selected desktop session.
   - Quickshell exits immediately; Cage terminates as its child application closes.
   - `greetd` takes over the console and starts your desktop session as your logged-in user.

---

## Installation & Setup

1. **Run the installer:**
   ```bash
   sudo ./greeter/install.sh
   ```
   This will:
   - Create `/var/cache/greetd/` with shared read/write permissions for user state and wallpaper caching.
   - Copy the greeter files to `/etc/greetd/greeter/`.
   - Copy `config.toml` and the fallback compositor configs to `/etc/greetd/`.
   - Create the `greeter` system user if it doesn't exist (greetd normally provides it), and add it to the `video` and `input` groups.
   - Grant the `greeter` user directory-traversal ACLs on `/home/*` and read access to `~/Pictures`.

2. **Enable greetd:**
   ```bash
   sudo systemctl enable greetd.service
   ```
   *(Note: If you have another display manager enabled like SDDM, disable it first: `sudo systemctl disable sddm.service`)*
