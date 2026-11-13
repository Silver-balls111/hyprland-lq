#!/usr/bin/env bash
# install.sh — Setup and install Quickshell greetd greeter
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root / with sudo: sudo ./greeter/install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Setting up /var/cache/greetd cache directory..."
mkdir -p /var/cache/greetd
chmod 777 /var/cache/greetd

echo "==> Installing greeter configuration to /etc/greetd/..."
mkdir -p /etc/greetd/greeter
cp -r "$SCRIPT_DIR"/* /etc/greetd/greeter/

# Place hyprland config and config.toml in /etc/greetd
cp -f "$SCRIPT_DIR/hyprland.conf" /etc/greetd/hyprland.conf
cp -f "$SCRIPT_DIR/hyprland.lua" /etc/greetd/hyprland.lua
cp -f "$SCRIPT_DIR/config.toml" /etc/greetd/config.toml

# Ensure permissions
chmod 644 /etc/greetd/config.toml
chmod 644 /etc/greetd/hyprland.conf
chmod 644 /etc/greetd/hyprland.lua
chmod -R a+rX /etc/greetd/greeter

# Ensure the greeter user exists (greetd's package normally creates it; a
# system-user fallback keeps a fresh machine from failing greetd at boot)
if ! id "greeter" &>/dev/null; then
    useradd -r -M -d /var/lib/greeter -s /usr/bin/nologin greeter
    echo "    Created system user 'greeter'"
fi

# Add greeter user to video and input groups if not already
if id "greeter" &>/dev/null; then
    usermod -a -G video,input greeter 2>/dev/null || true
fi

echo "==> Greeter wallpaper state..."
# Point /var/cache/greetd/wallpaper (symlink) to current wallpaper
# and grant user greeter ACLs to traverse /home/<user> and read Pictures.
WALL_SRC=""
if command -v awww &>/dev/null; then
    WALL_SRC=$(awww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -n 1 || true)
fi
if [ -z "$WALL_SRC" ] || [ ! -f "$WALL_SRC" ]; then
    for uhome in /home/*; do
        if [ -d "$uhome/Pictures/wallpapers" ]; then
            WALL_SRC=$(find "$uhome/Pictures/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | head -n 1 || true)
            [ -n "$WALL_SRC" ] && break
        fi
    done
fi
if [ -n "$WALL_SRC" ] && [ -f "$WALL_SRC" ]; then
    ln -sfn "$WALL_SRC" /var/cache/greetd/.wallpaper.tmp
    mv -Tf /var/cache/greetd/.wallpaper.tmp /var/cache/greetd/wallpaper
    echo "    Symlinked wallpaper -> $WALL_SRC"
fi

# Ensure user greeter can traverse into user homes and read wallpapers
for uhome in /home/*; do
    if [ -d "$uhome" ]; then
        setfacl -m u:greeter:--x "$uhome" 2>/dev/null || true
        if [ -d "$uhome/Pictures" ]; then
            setfacl -R -m u:greeter:rX "$uhome/Pictures" 2>/dev/null || true
            setfacl -R -d -m u:greeter:rX "$uhome/Pictures" 2>/dev/null || true
        fi
    fi
done

echo "==> Seeding matugen palette for the greeter..."
# The greeter user cannot read ~/.local/state, so the bar copies colors.json
# here on every wallpaper apply. Seed from whichever user's generated file
# exists so the first boot after install is already on the live palette.
for f in /home/*/.local/state/quickshell/generated/colors.json; do
    if [ -f "$f" ]; then
        cp -f "$f" /var/cache/greetd/colors.json
        chmod a+r /var/cache/greetd/colors.json
        break
    fi
done

echo "==> Installation complete!"
echo "To test the greeter UI without logging out, run:"
echo "    quickshell -p $SCRIPT_DIR/shell.qml"
echo ""
echo "To enable greetd on boot, run:"
echo "    sudo systemctl enable greetd.service"
