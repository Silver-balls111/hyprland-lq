pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// GreeterState — everything that must be exactly ONE per system, even with
// one Greeter UI per screen (shell.qml spawns one Greeter per monitor).
// Wallpaper/user/session discovery, the Greetd auth state machine and the
// typed buffer live here; Greeter.qml instances are pure UI binding to this
// singleton. Without it, second-screen instances cancel each other's live
// Greetd sessions (startAuth() → cancelSession → createSession) and race
// their discovery procs on the same cache files.
//
// Must be kicked with init() from shell.qml — Quickshell singletons do
// nothing until first touched (same trap as ScreenTime.init()).
Singleton {
    id: root

    // ── Session & User state ───────────────────────────────────────────────
    property var users: []
    property string currentUser: ""
    property var sessions: []
    property var currentSession: null
    property string wallpaperPath: ""

    // ── Auth state ─────────────────────────────────────────────────────────
    property string buffer: ""
    // idle | authenticating | failed | launching
    property string authState: "idle"
    property string pendingPassword: ""
    property bool capsOn: false

    function init() {
        wallpaperFinderProc.running = true;
        usersProbe.running = true;
        sessionsProbe.running = true;
    }

    // ── Keyboard handling ──────────────────────────────────────────────────
    // Popup Esc/Enter interception lives in Greeter (it owns the popup
    // state); everything from here on is the password state machine.
    function handleKey(event) {
        const k = event.key;
        if (k === Qt.Key_CapsLock) {
            event.accepted = true;
            capsOn = !capsOn;
            return;
        }
        if (k === Qt.Key_Escape) {
            event.accepted = true;
            buffer = "";
            if (authState === "failed") authState = "idle";
            return;
        }
        if (k === Qt.Key_Backspace) {
            event.accepted = true;
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1);
            return;
        }
        if (k === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true;
            buffer = "";
            return;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            event.accepted = true;
            submit();
            return;
        }
        if (event.text.length === 1 && event.text >= " " && event.text < "\x7f"
            && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            event.accepted = true;
            // Typing after a failure starts the next attempt
            if (authState === "failed") authState = "idle";
            if (buffer.length < 64) buffer += event.text;
        }
    }

    // ── Greetd Authentication logic ────────────────────────────────────────
    function startAuth(username) {
        if (!username) return;
        currentUser = username;
        buffer = "";
        authState = "idle";
        pendingPassword = "";

        if (!Greetd.available) {
            console.warn("greeter: Running in standalone / test preview mode (no Greetd socket)");
            return;
        }

        if (Greetd.state !== GreetdState.Inactive) {
            try { Greetd.cancelSession(); } catch(e) {}
        }
        Greetd.createSession(username);
    }

    function submit() {
        if (buffer === "" || authState === "authenticating" || authState === "launching") return;
        // No usable user (e.g. empty user list or parse failure) — nothing to
        // authenticate against; wait for a real pick from the dropdown.
        if (currentUser === "") return;

        if (!Greetd.available) {
            // Preview mode test simulation
            authState = "authenticating";
            testTimer.restart();
            return;
        }

        if (Greetd.state === GreetdState.Authenticating) {
            authState = "authenticating";
            Greetd.respond(buffer);
        } else {
            pendingPassword = buffer;
            if (Greetd.state === GreetdState.Inactive) {
                Greetd.createSession(currentUser);
            }
        }
    }

    Timer {
        id: testTimer
        interval: 700
        onTriggered: {
            root.authState = "failed";
            root.buffer = "";
        }
    }

    Timer {
        id: retryTimer
        interval: 1000
        onTriggered: {
            if (Greetd.available && Greetd.state === GreetdState.Inactive) {
                Greetd.createSession(root.currentUser);
            }
        }
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (root.pendingPassword !== "") {
                    const pw = root.pendingPassword;
                    root.pendingPassword = "";
                    root.authState = "authenticating";
                    Greetd.respond(pw);
                }
            }
        }
        function onAuthFailure(message) {
            console.warn("greeter: auth failed:", message);
            // Plain "Login Failed" feedback: the field is cleared and stays in
            // the failed state until the user types again (handleKey resets it)
            root.authState = "failed";
            root.buffer = "";
            root.pendingPassword = "";
            retryTimer.restart();
        }
        function onReadyToLaunch() {
            root.authState = "launching";
            root.saveLastState();

            const cmd = root.getCommandList(root.currentSession ? root.currentSession.exec : "Hyprland");
            const env = root.getSessionEnv(root.currentSession);
            Greetd.launch(cmd, env, true);
        }
        function onError(error) {
            // Same failed contract as onAuthFailure: clear the field, expose
            // "Login Failed", schedule the retry session. Not clearing left
            // dots parked on screen with no visible feedback.
            console.warn("greeter: Greetd error:", error);
            root.authState = "failed";
            root.buffer = "";
            root.pendingPassword = "";
            retryTimer.restart();
        }
    }

    function getCommandList(execStr) {
        if (!execStr) return ["Hyprland"];
        return execStr.trim().split(/\s+/);
    }

    // Percent-encode each segment of an absolute path — paths containing
    // spaces or '#' break a bare "file://" + path URL (wallpaper, ~/.face)
    function fileUrl(path) {
        if (path === "") return "";
        if (path.startsWith("/"))
            return "file://" + path.split("/").map(encodeURIComponent).join("/");
        return path;
    }

    function getSessionEnv(session) {
        const env = [];
        if (session && session.type === "wayland") {
            env.push("XDG_SESSION_TYPE=wayland");
            if (session.name.toLowerCase().includes("hyprland")) {
                env.push("XDG_CURRENT_DESKTOP=Hyprland");
                env.push("XDG_SESSION_DESKTOP=Hyprland");
            }
        } else {
            env.push("XDG_SESSION_TYPE=x11");
        }
        return env;
    }

    function saveLastState() {
        if (!currentUser) return;
        const sessionName = currentSession ? currentSession.name : "Hyprland";
        stateSaverProc.command = ["sh", "-c",
            'mkdir -p /var/cache/greetd 2>/dev/null || true; ' +
            'echo "$1" > /var/cache/greetd/last-user 2>/dev/null || true; ' +
            'echo "$2" > /var/cache/greetd/last-session 2>/dev/null || true',
            "sh", currentUser, sessionName
        ];
        stateSaverProc.running = true;
    }

    Process { id: stateSaverProc; command: [] }

    // ── Wallpaper discovery process ────────────────────────────────────────
    // Live system reads /var/cache/greetd/wallpaper (atomic symlink, see
    // install.sh / Actions.syncGreetdWallpaper). In preview mode or
    // fallbacks, query awww or fall back to the bundled asset.
    Process {
        id: wallpaperFinderProc
        command: ["sh", "-c",
            'p=""; ' +
            'if [ -f /var/cache/greetd/wallpaper ]; then ' +
            '    p=/var/cache/greetd/wallpaper; ' +
            'elif command -v awww >/dev/null 2>&1 && [ -n "$(awww query 2>/dev/null)" ]; then ' +
            '    p=$(awww query 2>/dev/null | grep -oP "(?<=image: ).*" | head -n 1 || true); ' +
            'elif [ -f /var/cache/greetd/wallpaper-path ] && [ -f "$(cat /var/cache/greetd/wallpaper-path 2>/dev/null)" ]; then ' +
            '    p=$(cat /var/cache/greetd/wallpaper-path); ' +
            'elif [ -f /tmp/greetd-wallpaper.png ]; then ' +
            '    p=/tmp/greetd-wallpaper.png; ' +
            'fi; ' +
            'echo "$p"']
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "") {
                    root.wallpaperPath = p;
                } else {
                    root.wallpaperPath = Qt.resolvedUrl("assets/wallpaper.jpg");
                }
            }
        }
    }

    // ── User discovery process ─────────────────────────────────────────────
    Process {
        id: usersProbe
        command: ["python3", "-c",
            'import pwd, json, os\n' +
            'users = []\n' +
            'for p in pwd.getpwall():\n' +
            '    if 1000 <= p.pw_uid < 60000 and not p.pw_shell.endswith("nologin") and not p.pw_shell.endswith("false"):\n' +
            '        avatar = ""\n' +
            '        for fp in [os.path.join(p.pw_dir, ".face"), os.path.join(p.pw_dir, ".face.icon")]:\n' +
            '            if os.path.exists(fp):\n' +
            '                avatar = fp\n' +
            '                break\n' +
            '        users.append({\n' +
            '            "name": p.pw_name,\n' +
            '            "gecos": p.pw_gecos.split(",")[0] if p.pw_gecos else p.pw_name,\n' +
            '            "uid": p.pw_uid,\n' +
            '            "home": p.pw_dir,\n' +
            '            "avatar": avatar\n' +
            '        })\n' +
            'last_user = ""\n' +
            'if os.path.exists("/var/cache/greetd/last-user"):\n' +
            '    try:\n' +
            '        with open("/var/cache/greetd/last-user") as f: last_user = f.read().strip()\n' +
            '    except: pass\n' +
            'print(json.dumps({"users": users, "lastUser": last_user}))\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.users = data.users || [];
                    let picked = data.lastUser;
                    if (!picked || !root.users.find(u => u.name === picked)) {
                        picked = root.users.length > 0 ? root.users[0].name : "";
                    }
                    root.currentUser = picked;
                    root.startAuth(picked);
                } catch(e) {
                    console.warn("greeter: user parse failed:", e);
                    root.currentUser = "";
                }
            }
        }
    }

    // ── Sessions discovery process ─────────────────────────────────────────
    Process {
        id: sessionsProbe
        command: ["python3", "-c",
            'import glob, os, json\n' +
            'sessions = []\n' +
            'files = glob.glob("/usr/share/wayland-sessions/*.desktop") + glob.glob("/usr/share/xsessions/*.desktop")\n' +
            'for f in sorted(files):\n' +
            '    try:\n' +
            '        name, exec_cmd = "", ""\n' +
            '        with open(f, "r", encoding="utf-8", errors="ignore") as fp:\n' +
            '            for line in fp:\n' +
            '                line = line.strip()\n' +
            '                if line.startswith("Name=") and not name:\n' +
            '                    name = line.split("=", 1)[1]\n' +
            '                elif line.startswith("Exec=") and not exec_cmd:\n' +
            '                    exec_cmd = line.split("=", 1)[1]\n' +
            '        stype = "wayland" if "wayland" in f else "x11"\n' +
            '        if name and exec_cmd:\n' +
            '            sessions.append({"name": name, "exec": exec_cmd, "type": stype, "file": f})\n' +
            '    except: pass\n' +
            'if not sessions:\n' +
            '    sessions = [{"name": "Hyprland", "exec": "/usr/bin/start-hyprland", "type": "wayland"}]\n' +
            'last_session = ""\n' +
            'if os.path.exists("/var/cache/greetd/last-session"):\n' +
            '    try:\n' +
            '        with open("/var/cache/greetd/last-session") as f: last_session = f.read().strip()\n' +
            '    except: pass\n' +
            'print(json.dumps({"sessions": sessions, "lastSession": last_session}))\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.sessions = data.sessions || [];
                    let picked = null;
                    if (data.lastSession) {
                        picked = root.sessions.find(s => s.name === data.lastSession);
                    }
                    if (!picked) {
                        // Default preference: Hyprland, then Hyprland (uwsm-managed)
                        picked = root.sessions.find(s => s.name === "Hyprland")
                            || root.sessions.find(s => s.name === "Hyprland (uwsm-managed)")
                            || (root.sessions.length > 0 ? root.sessions[0] : { name: "Hyprland", exec: "/usr/bin/start-hyprland", type: "wayland" });
                    }
                    root.currentSession = picked;
                } catch(e) {
                    console.warn("greeter: sessions parse failed:", e);
                    root.currentSession = { name: "Hyprland", exec: "/usr/bin/start-hyprland", type: "wayland" };
                }
            }
        }
    }
}
