import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower

Item {
    id: root

    // The one-per-system state singleton (discovery procs + Greetd auth
    // machine + typed buffer). shell.qml spawns one Greeter per monitor;
    // without hoisting, the instances would cancel each other's live
    // Greetd sessions and race their discovery procs.
    readonly property QtObject gs: GreeterState

    // Pure UI over the singleton; all of these are read-only forwards.
    readonly property var users: gs.users
    readonly property string currentUser: gs.currentUser
    readonly property var sessions: gs.sessions
    readonly property var currentSession: gs.currentSession
    readonly property string wallpaperPath: gs.wallpaperPath
    readonly property string buffer: gs.buffer
    property bool wallDark: false

    readonly property color lockFg: wallDark ? "#f2f2f2" : Theme.fg
    readonly property color lockFgMuted: wallDark ? Qt.rgba(1, 1, 1, 0.62) : Theme.fgMuted

    // Auth state + caps lock live in the singleton (keyboard can land on any
    // screen; the auth machine is global)
    readonly property string authState: gs.authState

    // Public knobs for the dropdown state (test harness pokes it — same
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
        // While any popup is open the keyboard belongs to the menus: Esc
        // closes them and Return is swallowed (accidental submit while the
        // dropdown is open must not log you in with a stale user).
        if (sessionSelector.open || powerMenu.open || userSelector.open) {
            if (event.key === Qt.Key_Escape) {
                sessionSelector.open = false;
                powerMenu.open = false;
                userSelector.open = false;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                return;
            }
        }
        gs.handleKey(event);
    }

    // ── Greetd-driven functions forwarded from GreeterState ────────────────
    function startAuth(uname) { gs.startAuth(uname); }
    function submit() { gs.submit(); }

    function saveLastState() { gs.saveLastState(); }

    // Percent-encode each path segment — a wallpaper under a directory with
    // spaces or a '#' breaks a bare "file://" + path URL
    function wallUrl(path) {
        return gs.fileUrl(path);
    }

    // ── Background: blurred wallpaper (matching Lockscreen.qml) ───────────
    Rectangle { anchors.fill: parent; color: "#000000" }

    Image {
        id: wall
        visible: false
        anchors.fill: parent
        anchors.margins: -64 // blur samples transparent padding at edges
        source: root.wallpaperPath !== "" ? root.wallUrl(root.wallpaperPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // Same downsampling as Lockscreen: decode bounded to ~window width
        // instead of the native 4K/8K decode. A full-res decode gets aliased
        // while scaling into the window, and blur applied on top of that
        // aliasing reads as an "oil painting" smear.
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

        // Profile photo with smooth circle rounding, falling back to initial-letter circle
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 80
            height: 80

            // Initial-letter fallback circle
            Rectangle {
                anchors.fill: parent
                radius: 40
                color: Theme.userAvatarColor(root.currentUser)
                visible: avatarImg.imgStatus !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: root.currentUser !== "" ? root.currentUser.charAt(0).toUpperCase() : "?"
                    color: "#f2f2f2"
                    font.family: Theme.fontFamily
                    font.pixelSize: 36
                }
            }

            RoundedImage {
                id: avatarImg
                anchors.fill: parent
                rounding: 40
                source: {
                    const u = root.users.find(x => x.name === root.currentUser);
                    if (u && u.avatar) return gs.fileUrl(u.avatar);
                    return Qt.resolvedUrl("assets/pfp.png");
                }
            }
        }

        // User switcher pill — toggles the dropdown below
        Pill {
            id: userPill
            anchors.horizontalCenter: parent.horizontalCenter
            active: userSelector.open
            transparent: true
            onClicked: {
                sessionSelector.open = false;
                powerMenu.open = false;
                userSelector.open = !userSelector.open;
            }

            readonly property color contentFg: filled ? Theme.fg : root.lockFg
            readonly property color contentFgMuted: filled ? Theme.fgMuted : root.lockFgMuted

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const u = root.users.find(x => x.name === root.currentUser);
                    return u ? (u.gecos || u.name) : root.currentUser;
                }
                color: userPill.contentFg
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }

            NIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: userSelector.open ? "chevronUp" : "chevronDown"
                iconSize: 12
                iconColor: userPill.contentFgMuted
            }
        }

        // Scrollable user dropdown — inserted in the flow; the Column skips
        // it while hidden, so the password field only shifts down when open
        UserSelector {
            id: userSelector
            anchors.horizontalCenter: parent.horizontalCenter
            users: root.users
            activeUser: root.currentUser
            fgColor: root.lockFg
            wallDark: root.wallDark
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
                color: root.wallDark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                border.width: 1
                border.color: root.wallDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)
                clip: true

                // Submit arrow — reserved lane on the right so dots never
                // sit under it. Dots flick horizontally in the leftover width.
                // Adaptive fill: light glass on a dark wallpaper, dark glass
                // on a light one — a fixed white circle went near-invisible
                // on light wallpapers.
                Rectangle {
                    id: submitBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: 17
                    color: root.wallDark
                        ? (submitMouse.containsMouse || submitTap.pressed
                            ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.16))
                        : (submitMouse.containsMouse || submitTap.pressed
                            ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(0, 0, 0, 0.18))
                    border.width: 1
                    border.color: root.wallDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.26)
                    visible: root.buffer.length > 0 && root.authState !== "launching"
                    z: 2

                    NIcon {
                        anchors.centerIn: parent
                        name: "arrowRight"
                        iconSize: 14
                        iconColor: root.lockFg
                    }

                    TapHandler {
                        id: submitTap
                        onTapped: root.submit()
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

                    readonly property real dotsWidth: root.buffer.length > 0 ? (root.buffer.length * 13 - 3) : 0
                    contentWidth: Math.max(width, dotsWidth)
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentWidth > width

                    function scrollToEnd() {
                        if (dotsWidth > width)
                            contentX = dotsWidth - width;
                        else
                            contentX = 0;
                    }

                    onDotsWidthChanged: scrollToEnd()
                    onWidthChanged: scrollToEnd()

                    WheelHandler {
                        target: dotsFlick
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            dotsFlick.contentX = Math.max(0, Math.min(dotsFlick.contentWidth - dotsFlick.width, dotsFlick.contentX - delta));
                        }
                    }

                    Row {
                        id: dotsRow
                        spacing: 3
                        height: parent.height
                        width: dotsFlick.dotsWidth
                        x: width < dotsFlick.width
                            ? Math.round((dotsFlick.width - width) / 2) : 0

                        Repeater {
                            model: root.buffer.length
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: root.lockFgMuted
                                opacity: 0.9
                            }
                        }
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
            visible: gs.capsOn
            text: "Caps Lock active"
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    // ── Outside click / tap dismisser for popups ───────────────────────────
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

        TapHandler {
            onTapped: {
                sessionSelector.open = false;
                powerMenu.open = false;
                userSelector.open = false;
            }
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
        fgColor: root.lockFg
        fgMutedColor: root.lockFgMuted
        onOpenChanged: if (open) userSelector.open = false;
        onSessionSelected: sess => {
            gs.currentSession = sess;
            gs.saveLastState();
        }
    }

    // ── Bottom-Right: Power Menu ───────────────────────────────────────────
    PowerMenu {
        id: powerMenu
        z: 50
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 28
        fgColor: root.lockFg
        onOpenChanged: if (open) userSelector.open = false;
    }
}
