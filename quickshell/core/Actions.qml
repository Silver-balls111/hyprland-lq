pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent fire-and-forget action runners. The popup panels are created
// lazily and DESTROYED on close (Loader { active: Popups.active === ... }) —
// a Process owned by a popup dies with that popup, so any action that must
// complete after the popup closes lives HERE, at singleton scope. Popups set
// arguments and call these functions right before Popups.close(); the
// Process keeps running.
//
// NB: never move these back into Wallswitch — the memory pass
// (c5dfbe8) silently broke apply exactly that way (popup closes -> Loader
// destroys the tree -> the freshly started Process dies with it).
Item {
    id: root

    // ---- wallpaper apply: awww transition + matugen palette regen ----
    // awww failure short-circuits matugen (&&), so the palette can never
    // desync from the wallpaper.
    // The greetd greeter follows /var/cache/greetd/wallpaper — a symlink re-
    // pointed at the current wallpaper after every apply (tmp+mv swap, no
    // image data is ever copied).
    Process {
        id: applyProc
        property string path: ""
        property string trans: "fade"
        // path/trans arrive as positional args — no quoting hazards
        command: ["sh", "-c",
            'awww img "$1" --transition-type "$2" --transition-duration 1.2 --transition-fps 60' +
            ' && matugen image "$1" --prefer darkness --config "$HOME/.config/matugen/config.toml"' +
            ' && (mkdir -p /var/cache/greetd 2>/dev/null; ln -sfn "$1" /var/cache/greetd/.wallpaper.tmp 2>/dev/null && mv -Tf /var/cache/greetd/.wallpaper.tmp /var/cache/greetd/wallpaper 2>/dev/null || true)' +
            ' && (cp -f "$HOME/.local/state/quickshell/generated/colors.json" /var/cache/greetd/colors.json 2>/dev/null && chmod a+r /var/cache/greetd/colors.json 2>/dev/null || true)',
            "sh", path, trans]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) console.warn("wallswitch: apply stderr:", text.trim());
            }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("wallswitch: apply failed, exit code", code);
        }
    }

    function applyWallpaper(path, trans) {
        if (!path) return;
        applyProc.path = path;
        applyProc.trans = trans || "fade";
        applyProc.running = true;
    }

    // ---- greetd wallpaper sync: re-point the greeter symlink before power actions ----
    Process {
        id: syncGreetdProc
        command: ["sh", "-c",
            'WALL=$(awww query 2>/dev/null | grep -oP "(?<=image: ).*" | head -n 1 || true); ' +
            'if [ -n "$WALL" ] && [ -f "$WALL" ]; then ' +
            '    mkdir -p /var/cache/greetd 2>/dev/null || true; ' +
            '    ln -sfn "$WALL" /var/cache/greetd/.wallpaper.tmp 2>/dev/null && mv -Tf /var/cache/greetd/.wallpaper.tmp /var/cache/greetd/wallpaper 2>/dev/null || true; ' +
            'fi; ' +
            'if [ -f "$HOME/.local/state/quickshell/generated/colors.json" ]; then ' +
            '    cp -f "$HOME/.local/state/quickshell/generated/colors.json" /var/cache/greetd/colors.json 2>/dev/null && chmod a+r /var/cache/greetd/colors.json 2>/dev/null || true; ' +
            'fi']
    }

    function syncGreetdWallpaper() {
        syncGreetdProc.running = true;
    }
}

