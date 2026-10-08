#!/usr/bin/env bash
# save-wallpaper.sh — Point /var/cache/greetd/wallpaper (a symlink) at the
# current awww wallpaper so the greetd login screen always shows the live
# system wallpaper. No image data is copied — the greeter reads the file
# in place through the symlink.

set -euo pipefail

CACHE_DIR="/var/cache/greetd"
LINK="$CACHE_DIR/wallpaper"

# Query awww for current wallpaper
WALLPAPER=$(awww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -n 1 || true)

if [ -z "$WALLPAPER" ]; then
    # Try finding wallpaper from user Pictures folder
    WALLPAPER=$(find "$HOME/Pictures/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | head -n 1 || true)
fi

if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    if mkdir -p "$CACHE_DIR" 2>/dev/null && [ -w "$CACHE_DIR" ]; then
        # Atomic swap: build the link under a temp name, then rename over
        ln -sfn "$WALLPAPER" "$CACHE_DIR/.wallpaper.tmp"
        mv -Tf "$CACHE_DIR/.wallpaper.tmp" "$LINK"
        echo "Greeter wallpaper -> $WALLPAPER"
    else
        echo "Cannot write to $CACHE_DIR — run 'sudo ./greeter/install.sh' first" >&2
        exit 1
    fi
else
    echo "No active wallpaper found" >&2
    exit 1
fi
