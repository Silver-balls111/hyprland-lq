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

# Add greeter user to video group if not already
if id "greeter" &>/dev/null; then
    usermod -a -G video greeter 2>/dev/null || true
fi

echo "==> Greeter wallpaper state..."
# The user session re-points /var/cache/greetd/wallpaper (a symlink) at the
# current awww wallpaper on every change — the greeter reads through it, no
# image copies. Remove legacy artifacts from the old copy-based flow.
rm -f /var/cache/greetd/wallpaper.png /var/cache/greetd/wallpaper-path 2>/dev/null || true
rm -f /tmp/greetd-wallpaper.png 2>/dev/null || true

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

echo "==> Granting the greeter user read access to wallpapers..."
# Homes are 0700, so the 'greeter' user needs an ACL to traverse into them
# and read the wallpaper files the symlink points at. Only the greeter user
# is granted anything, and only traverse (x) on the home itself.
if command -v setfacl &>/dev/null; then
    for uhome in /home/*; do
        [ -d "$uhome" ] || continue
        setfacl -m u:greeter:--x "$uhome" 2>/dev/null || true
        if [ -d "$uhome/Pictures/wallpapers" ]; then
            setfacl -R -m u:greeter:rX "$uhome/Pictures/wallpapers" 2>/dev/null || true
            # Default ACL: future wallpapers stay readable for the greeter
            setfacl -d -m u:greeter:rX "$uhome/Pictures/wallpapers" 2>/dev/null || true
        fi
    done
else
    echo "    setfacl not found — install the 'acl' package, otherwise the"
    echo "    greeter cannot follow the wallpaper symlink into /home."
fi

echo "==> Installation complete!"
echo "To test the greeter UI without logging out, run:"
echo "    quickshell -p $SCRIPT_DIR/shell.qml"
echo ""
echo "To enable greetd on boot, run:"
echo "    sudo systemctl enable greetd.service"
