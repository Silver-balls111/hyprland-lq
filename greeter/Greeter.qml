import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Services.UPower

Item {
    id: root

    // ── Session & User state ───────────────────────────────────────────────
    property var users: []
    property string currentUser: ""
    property var sessions: []
    property var currentSession: null
    property string wallpaperPath: ""
    property bool wallDark: false

    readonly property color lockFg: wallDark ? "#f2f2f2" : Theme.fg
    readonly property color lockFgMuted: wallDark ? Qt.rgba(1, 1, 1, 0.70) : Theme.fgMuted

    // ── Auth state ─────────────────────────────────────────────────────────
    property string buffer: ""
    // idle | authenticating | failed | launching
    property string authState: "idle"
    property string pendingPassword: ""
    property bool capsOn: false

    // Public knob for the dropdown state (test harness pokes it — same
    // pattern as the lockscreen's test hooks)
    property alias userMenuOpen: userSelector.open
    property alias sessionMenuOpen: sessionSelector.open

    // ── Clock ──────────────────────────────────────────────────────────────
    SystemClock {
        id: clockObj
        precision: SystemClock.Minutes
    }
    readonly property var now: clockObj.date
    readonly property string timeText: {
        const h = now.getHours() % 12;
        return String(h === 0 ? 12 : h).padStart(2, "0") + ":"
            + String(now.getMinutes()).padStart(2, "0");
    }
    readonly property string ampmText: now.getHours() < 12 ? "AM" : "PM"

    // ── Battery ────────────────────────────────────────────────────────────
    readonly property var batt: UPower.displayDevice
    readonly property bool battVisible: batt && batt.ready && batt.isPresent
        && (batt.isLaptopBattery || batt.percentage > 0)
    readonly property bool battCharging: batt && batt.state === UPowerDeviceState.Charging

    // ── Keyboard handling ──────────────────────────────────────────────────
    focus: true
    Keys.onPressed: event => handleKey(event)

    function handleKey(event) {
        if (sessionSelector.open || powerMenu.open || userSelector.open) {
            if (event.key === Qt.Key_Escape) {
                sessionSelector.open = false;
                powerMenu.open = false;
                userSelector.open = false;
                event.accepted = true;
                return;
            }
        }

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
        if (event.text.length === 1 && event.text >= " "
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
            console.warn("greeter: Greetd error:", error);
            root.authState = "failed";
        }
    }

    function getCommandList(execStr) {
        if (!execStr) return ["Hyprland"];
        return execStr.trim().split(/\s+/);
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
    // The user session re-points /var/cache/greetd/wallpaper (a symlink) at
    // the current awww wallpaper on every change — no image is ever copied.
    // The remaining entries are legacy fallbacks from the old copy-based flow.
    Process {
        id: wallpaperFinderProc
        command: ["sh", "-c",
            'p=""; ' +
            'if [ -f /var/cache/greetd/wallpaper ]; then ' +
            '    p=/var/cache/greetd/wallpaper; ' +
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
                        picked = root.users.length > 0 ? root.users[0].name : "bandit";
                    }
                    root.currentUser = picked;
                    root.startAuth(picked);
                } catch(e) {
                    console.warn("greeter: user parse failed:", e);
                    root.currentUser = "bandit";
                    root.startAuth("bandit");
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
                        // Default preference: Hyprland (uwsm) or Hyprland
                        picked = root.sessions.find(s => s.name === "Hyprland (uwsm-managed)")
                            || root.sessions.find(s => s.name === "Hyprland")
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

    Component.onCompleted: {
        wallpaperFinderProc.running = true;
        usersProbe.running = true;
        sessionsProbe.running = true;
    }

    // ── Background: blurred wallpaper ──────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#000000" }

    Image {
        id: wall
        visible: false
        anchors.fill: parent
        anchors.margins: -64
        source: root.wallpaperPath !== "" ? (root.wallpaperPath.startsWith("/") ? "file://" + root.wallpaperPath : root.wallpaperPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(128, Math.round((root.width + 128) / 128) * 128)
        sourceSize.height: 0
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blurMax: 64
        blur: 1.0
    }

    // Subtle dark vignette overlay for legibility
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
    }

    // ── Luminance sampler for adaptive contrast ────────────────────────────
    Canvas {
        id: lumSampler
        visible: false
        width: 16
        height: 9
        readonly property string wallUrl: wall.source.toString()
        property bool decodePending: false
        property int retries: 0

        onWallUrlChanged: {
            retries = 0;
            decodePending = false;
            if (wallUrl !== "") loadImage(wallUrl);
        }
        Component.onCompleted: {
            if (wallUrl !== "") { decodePending = true; loadImage(wallUrl); }
        }
        onImageLoaded: sample()
        onAvailableChanged: if (available && decodePending) loadImage(wallUrl)

        function sample() {
            if (!available) { decodePending = true; return; }
            if (wallUrl === "") return;
            const ctx = getContext("2d");
            if (!ctx) { decodePending = true; return; }
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(wallUrl, 0, 0, width, height);
            const d = ctx.getImageData(0, 0, width, height).data;
            let sum = 0, covered = 0;
            for (let i = 0; i < d.length; i += 4) {
                sum += 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
                if (d[i + 3] !== 0) covered++;
            }
            if (covered === 0) {
                if (retries < 5) {
                    retries++;
                    retrySampleTimer.restart();
                } else {
                    root.wallDark = true;
                    decodePending = false;
                }
                return;
            }
            root.wallDark = sum / (d.length / 4) < 128;
            decodePending = false;
        }
        Timer {
            id: retrySampleTimer
            interval: 250
            onTriggered: lumSampler.sample()
        }
    }

    // ── Top-right: Battery indicator (matching reference image) ────────────
    Row {
        id: battRow
        visible: root.battVisible
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 36
        anchors.topMargin: 32
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batt ? Math.round(root.batt.percentage * 100) + "%" : ""
            color: root.lockFgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 28
        }

        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.battCharging ? "batteryCharging" : "battery"
            level: root.batt ? root.batt.percentage : 0
            iconSize: 30
            iconColor: root.lockFgMuted
        }
    }

    // ── Center Clock + Date (lockscreen parity: 10% from top, 75px) ────────
    Item {
        id: timeBlock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.10)
        width: bigTime.width + 10 + apTime.width
        height: bigTime.height

        Text {
            id: bigTime
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: root.lockFgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 75
        }
        Text {
            id: apTime
            x: bigTime.width + 10
            anchors.baseline: bigTime.baseline
            text: root.ampmText
            color: root.lockFgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 75
        }
    }

    Text {
        id: dateLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: timeBlock.bottom
        anchors.topMargin: 10
        text: Qt.formatDate(root.now, "dddd, MMMM dd")
        color: root.lockFgMuted
        font.family: Theme.fontFamily
        font.pixelSize: 22
    }

    // ── Center User & Password Area ────────────────────────────────────────
    Column {
        id: centerArea
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 90
        spacing: 16
        width: 320
        // Above the outside-click dismisser (z: 40) so the pill and the open
        // dropdown keep receiving clicks while it is enabled
        z: 50

        // Initial-letter avatar (colored circle, no photo / ring)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 80
            height: 80

            Rectangle {
                anchors.fill: parent
                radius: 40
                color: Theme.userAvatarColor(root.currentUser)
            }

            Text {
                anchors.centerIn: parent
                text: root.currentUser !== "" ? root.currentUser.charAt(0) : "?"
                color: "#f2f2f2"
                font.family: Theme.fontFamily
                font.pixelSize: 36
            }
        }

        // User switcher pill — toggles the dropdown below
        Pill {
            id: userPill
            anchors.horizontalCenter: parent.horizontalCenter
            active: userSelector.open
            onClicked: {
                sessionSelector.open = false;
                powerMenu.open = false;
                userSelector.open = !userSelector.open;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const u = root.users.find(x => x.name === root.currentUser);
                    return u ? (u.gecos || u.name) : root.currentUser;
                }
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }

            NIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: userSelector.open ? "chevronUp" : "chevronDown"
                iconSize: 12
                iconColor: Theme.fgMuted
            }
        }

        // Scrollable user dropdown — inserted in the flow; the Column skips
        // it while hidden, so the password field only shifts down when open
        UserSelector {
            id: userSelector
            anchors.horizontalCenter: parent.horizontalCenter
            users: root.users
            activeUser: root.currentUser
            onOpenChanged: {
                if (open) {
                    sessionSelector.open = false;
                    powerMenu.open = false;
                }
            }
            onUserSelected: uname => root.startAuth(uname)
        }

        // Password input field
        Item {
            id: fieldContainer
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260
            height: 50

            Rectangle {
                id: fieldBackground
                anchors.fill: parent
                radius: 25
                color: Theme.inputBg
                border.width: 1
                border.color: Theme.border
                clip: true

                // Submit arrow — reserved lane on the right so dots never
                // sit under it. Dots flick horizontally in the leftover width.
                Rectangle {
                    id: submitBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: 17
                    color: submitMouse.containsMouse ? Theme.pillHover : Theme.pillBg
                    visible: root.buffer.length > 0 && root.authState !== "launching"
                    z: 2

                    NIcon {
                        anchors.centerIn: parent
                        name: "arrowRight"
                        iconSize: 14
                        iconColor: Theme.fg
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }

                Flickable {
                    id: dotsFlick
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 18
                    anchors.rightMargin: submitBtn.visible ? 50 : 18
                    height: 16
                    clip: true
                    visible: root.buffer.length > 0 && root.authState !== "launching"
                    contentWidth: Math.max(width, dotsRow.implicitWidth)
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentWidth > width

                    Row {
                        id: dotsRow
                        spacing: 5
                        height: parent.height
                        x: implicitWidth < dotsFlick.width
                            ? Math.round((dotsFlick.width - implicitWidth) / 2) : 0

                        Repeater {
                            model: root.buffer.length
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: root.lockFg
                                opacity: 0.95
                            }
                        }
                    }

                    function scrollToEnd() {
                        if (contentWidth > width)
                            contentX = contentWidth - width;
                        else
                            contentX = 0;
                    }
                }

                Connections {
                    target: root
                    function onBufferChanged() {
                        Qt.callLater(dotsFlick.scrollToEnd);
                    }
                }

                // Placeholder
                Text {
                    anchors.centerIn: parent
                    visible: root.buffer.length === 0 && root.authState !== "failed"
                        && root.authState !== "launching"
                    text: "Password"
                    color: root.lockFgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.authState === "launching"
                    text: "Launching..."
                    color: root.lockFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }

                // Failure feedback — plain text, no gradient ring; the buffer
                // is cleared on failure and typing resets to idle (handleKey)
                Text {
                    anchors.centerIn: parent
                    visible: root.authState === "failed" && root.buffer.length === 0
                    text: "Login Failed"
                    color: Theme.urgent
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
            }
        }

        // Caps Lock warning
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.capsOn
            text: "Caps Lock active"
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    // ── Outside click dismisser for popups ─────────────────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: sessionSelector.open || powerMenu.open || userSelector.open
        visible: enabled
        z: 40
        onClicked: {
            sessionSelector.open = false;
            powerMenu.open = false;
            userSelector.open = false;
        }
    }

    // ── Bottom-Left: Session Selector ──────────────────────────────────────
    SessionSelector {
        id: sessionSelector
        z: 50
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 28
        sessions: root.sessions
        currentSession: root.currentSession
        onOpenChanged: if (open) userSelector.open = false;
        onSessionSelected: sess => {
            root.currentSession = sess;
            root.saveLastState();
        }
    }

    // ── Bottom-Right: Power Menu ───────────────────────────────────────────
    PowerMenu {
        id: powerMenu
        z: 50
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 28
        onOpenChanged: if (open) userSelector.open = false;
        onWallpaperSaveRequested: {
            root.saveLastState();
        }
    }
}
