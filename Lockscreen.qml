import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland // re-exports GlobalShortcut (it has no module of its own)
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

// Session lock screen (hyprlock replacement). Lives inside the main shell
// instance: the WlSessionLock stays unlocked until something engages it —
//   · the "qs-bar:lock" GlobalShortcut (user binds e.g.
//     hl.bind("SUPER + L", hl.dsp.global("qs-bar:lock")))
//   · hypridle's lock_cmd, which can reach the same shortcut from a script
//     via the Lua eval socket: hyprctl eval 'hl.dsp.global("qs-bar:lock")'
//     (plain `hyprctl dispatch global ...` dies in Hyprland >= 0.56's parser)
//   · PowerPopup's Lock action, via the LockState singleton.
//
// Unlocking ONLY happens through PAM (password; no fingerprint support in
// PamContext). Never set LockState.engaged = false directly to bypass it —
// that is what TTY `loginctl unlock-session` is for when PAM is broken.
//
// Test/preview mode (agent + user convenience, does NOT lock the session):
//   LOCK_TEST=1 qs -p <throwaway file instantiating Lockscreen { testMode: true }>
// In test mode the same content renders in an Overlay-layer window; Enter
// simulates a wrong password instead of talking to PAM, and Esc closes the
// window when the buffer is empty.
// Root is an Item (QtObject has no default property, so it could not host
// the windows/processes/timers below); it stays invisible — the visuals live
// in the WlSessionLockSurface and, in test mode, the preview PanelWindow.
Item {
    id: root

    // ── knobs (hyprlock.conf parity) ──────────────────────────────────────
    // hyprlock "hide_input = true": one static indicator instead of dots
    property bool hideInput: false
    // hyprlock "dots_text_format = *": asterisks instead of dots
    property bool asteriskDots: false
    property string pamConfig: "login"   // /etc/pam.d/login — the same auth
    //   hyprlock gets (/etc/pam.d/hyprlock is literally "auth include login"),
    //   so no new PAM file is needed. Point it at "quickshell" if you ever
    //   create /etc/pam.d/quickshell with custom rules.
    property string profilePhotoPath: Quickshell.env("HOME") + "/Pictures/wallpapers/final_logo.png"
    property string weatherScript: Quickshell.env("HOME") + "/.config/hypr/hyprlock/weather.sh"

    // ── test/preview overrides (throwaway instances set these) ────────────
    property bool testMode: Quickshell.env("LOCK_TEST") === "1" // overridable by preview instances
    property bool testWindowVisible: true
    property string testPreview: ""   // rendered as the password buffer
    property string testState: ""     // rendered as authState ("checking"/"failed")
    property bool testCaps: false     // renders the caps-lock warning

    // ── runtime state ──────────────────────────────────────────────────────
    property string buffer: ""
    // idle | checking | failed | error
    property string authState: "idle"
    property string failMessage: ""
    property bool pendingSubmit: false
    property bool pamBroken: false
    property bool pamRetried: false
    property bool capsOn: false
    property string kbdLayout: ""
    property string weatherText: ""
    property string wallpaperPath: ""

    readonly property string effBuffer: testMode && testPreview !== "" ? testPreview : buffer
    readonly property string effState: testMode && testState !== "" ? testState : authState
    readonly property bool capsActive: (testMode && testCaps) || capsOn

    SystemClock {
        id: clockObj
        precision: SystemClock.Minutes
    }
    readonly property var now: clockObj.date
    // hyprlock $TIME12 parity: 12-hour clock. Qt's "hh" is only 12-hour when
    // AP appears in the SAME format string, and the AP label is a separate
    // (smaller) Text here — so compute the hour explicitly.
    readonly property string timeText: {
        const h = now.getHours() % 12;
        return String(h === 0 ? 12 : h).padStart(2, "0") + ":"
            + String(now.getMinutes()).padStart(2, "0");
    }
    readonly property string ampmText: now.getHours() < 12 ? "AM" : "PM"

    // ── services ───────────────────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property real sinkVolume: sink?.audio?.volume ?? 0
    readonly property bool micMuted: Pipewire.defaultAudioSource?.audio?.muted ?? true

    readonly property var batt: UPower.displayDevice
    readonly property bool battVisible: batt && batt.ready && batt.isPresent
        && (batt.isLaptopBattery || batt.percentage > 0)
    readonly property bool battCharging: batt && batt.state === UPowerDeviceState.Charging

    // only a PLAYING player gets the media card (parity with the old
    // widget-box-color.sh transparent-when-paused behavior)
    readonly property var activePlayer: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        return null;
    }
    readonly property bool fakeMedia: testMode && Quickshell.env("LOCK_FAKE_MEDIA") === "1"
    readonly property var mediaPlayer: fakeMedia
        ? { trackTitle: "Midnight City", trackArtists: "M83", trackArtUrl: "",
            canTogglePlaying: false, canGoNext: false, canGoPrevious: false }
        : activePlayer

    readonly property string statusText: {
        const parts = [];
        parts.push(sinkMuted ? "vol muted" : "vol " + Math.round(sinkVolume * 100) + "%");
        parts.push(micMuted ? "mic off" : "mic on");
        const a = Bluetooth.defaultAdapter;
        parts.push(!a || !a.enabled ? "bt off" : "bt on");
        return parts.join("  ·  ");
    }

    readonly property string kbdLayoutShort: {
        const m = /\(([^)]+)\)\s*$/.exec(kbdLayout);
        return m ? m[1] : kbdLayout;
    }

    // ── engage / unlock ────────────────────────────────────────────────────
    function engage() {
        if (LockState.engaged) return;
        Popups.close();
        buffer = "";
        authState = "idle";
        failMessage = "";
        pendingSubmit = false;
        pamBroken = false;
        pamRetried = false;
        wallpaperProc.running = true;
        weatherProc.running = true;
        if (!testMode && !pam.start()) {
            // Lock anyway (privacy) but tell the user auth is dead; recovery:
            // TTY -> loginctl unlock-session
            pamBroken = true;
            authState = "error";
            failMessage = "PAM unavailable — unlock via TTY: loginctl unlock-session";
            console.warn("lockscreen: pam.start() failed — /etc/pam.d/" + pamConfig + " missing or broken?");
        }
        LockState.engaged = true;
    }

    function unlock() {
        if (!LockState.engaged) return;
        LockState.engaged = false;
        buffer = "";
        authState = "idle";
        failMessage = "";
        pendingSubmit = false;
        pam.abort();
    }

    Connections {
        target: LockState
        function onEngagedChanged() {
            if (LockState.engaged) root.engage();
        }
    }

    GlobalShortcut {
        appid: "qs-bar"
        name: "lock"
        description: "Lock the session (quickshell lockscreen)"
        onPressed: root.testMode ? (root.testWindowVisible = !root.testWindowVisible)
                                 : root.engage()
    }

    // ── PAM ────────────────────────────────────────────────────────────────
    // pamMessage has NO parameters in 0.3.1 — read responseRequired/message
    // off the object after the signal fires.
    PamContext {
        id: pam
        config: root.pamConfig
        user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

        onPamMessage: {
            if (pam.responseRequired && root.pendingSubmit) {
                root.pendingSubmit = false;
                root.authState = "checking";
                pam.respond(root.buffer);
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            if (result === PamResult.Error) return; // the error signal handled it
            root.authState = "failed";
            root.failMessage = (pam.messageIsError && pam.message !== "")
                ? pam.message : "Wrong password";
            root.buffer = "";
            failResetTimer.restart();
            pam.start(); // re-arm the conversation for the next attempt
        }
        onError: err => {
            console.warn("lockscreen: PAM error", err);
            root.pamBroken = true;
            root.authState = "error";
            root.failMessage = "PAM error — unlock via TTY: loginctl unlock-session";
            // one silent retry per engage (covers transient start failures
            // without spamming start() forever while locked)
            if (!root.pamRetried) {
                root.pamRetried = true;
                pamRetryTimer.restart();
            }
        }
    }

    Timer { id: failResetTimer; interval: 3000
        onTriggered: {
            if (root.authState === "failed") { root.authState = "idle"; root.failMessage = ""; }
        }
    }
    Timer { id: pamRetryTimer; interval: 1500; onTriggered: pam.start() }

    function submit() {
        if (authState === "checking" || effBuffer === "") return;
        if (testMode) {
            // preview only — never touches PAM
            authState = "checking";
            testSimTimer.restart();
            return;
        }
        if (pam.responseRequired) {
            authState = "checking";
            pam.respond(buffer);
        } else {
            // PAM prompt has not arrived yet (fast typer / slow start)
            pendingSubmit = true;
        }
    }

    Timer { id: testSimTimer; interval: 900
        onTriggered: {
            root.authState = "failed";
            root.failMessage = "Wrong password (simulated)";
            root.buffer = "";
            failResetTimer.restart();
        }
    }

    function handleKey(event) {
        const k = event.key;
        if (k === Qt.Key_Escape) {
            event.accepted = true;
            if (buffer !== "") { buffer = ""; return; } // hyprlock: Esc clears
            if (testMode) testWindowVisible = false;    // preview: Esc closes
            return;
        }
        if (k === Qt.Key_Backspace) {
            event.accepted = true;
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1);
            return;
        }
        if (k === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true; // hyprlock: Ctrl+U clears
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
            if (buffer.length < 64) buffer += event.text;
        }
    }

    // ── session lock (surface component instantiated per screen) ───────────
    WlSessionLock {
        locked: LockState.engaged && !root.testMode

        WlSessionLockSurface {
            color: "#000000" // never leave the default white behind the wallpaper
            Loader {
                id: surfaceLoader
                anchors.fill: parent
                sourceComponent: lockContent
                onLoaded: item.forceActiveFocus()
            }
        }
    }

    // preview window (test mode only) — Overlay so it sits above the bar
    PanelWindow {
        visible: root.testMode && root.testWindowVisible
        anchors { left: true; right: true; top: true; bottom: true }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell:lockscreen-test"

        Loader {
            id: testLoader
            anchors.fill: parent
            sourceComponent: lockContent
            onLoaded: item.forceActiveFocus()
        }
        onVisibleChanged: {
            if (visible && testLoader.item) {
                testLoader.item.forceActiveFocus();
                testLoader.item.playFade();
            }
        }
    }

    // ── data processes ─────────────────────────────────────────────────────
    Process {
        id: wallpaperProc
        // same parse hyprlock-auto.sh used: `(?<=image: ).*`
        command: ["sh", "-c", "awww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "") root.wallpaperPath = p;
                else console.warn("lockscreen: awww query returned no wallpaper");
            }
        }
    }

    Process {
        id: devicesProbe
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const kbs = d.keyboards || [];
                    const main = kbs.find(k => k.main === true) || kbs[0];
                    if (main) {
                        root.capsOn = main.capsLock === true;
                        root.kbdLayout = main.active_keymap || "";
                    }
                } catch (e) {
                    console.warn("lockscreen: hyprctl devices parse failed:", e);
                }
            }
        }
    }
    // conf parity: capsLock label polled at 250ms; the same probe feeds the
    // keyboard-layout label
    Timer {
        id: devicesTimer
        interval: 250
        repeat: true
        running: LockState.engaged || root.testMode
        onTriggered: devicesProbe.running = true
    }

    Process {
        id: weatherProc
        // weather.sh prints from cache on a hit but NOT on a fresh fetch (it
        // only writes the cache file) — so cat the cache afterwards to cover
        // both paths. The script itself is used unmodified.
        command: ["sh", "-c", "bash \"$1\" >/dev/null 2>&1; cat /tmp/cache/wttr_cache.txt 2>/dev/null",
                  "sh", root.weatherScript]
        stdout: StdioCollector { onStreamFinished: root.weatherText = text.trim() }
        stderr: StdioCollector {}
    }
    Timer {
        id: weatherTimer
        interval: 60000
        repeat: true
        running: LockState.engaged || root.testMode
        onTriggered: weatherProc.running = true
    }

    Process {
        id: layoutSwitch
        command: ["hyprctl", "switchxkblayout", "all", "next"]
        // a top-level hyprctl command, NOT a dispatch — safe from scripts on
        // Hyprland >= 0.56 where flat dispatches die in the Lua parser
        onExited: (code, status) => { devicesProbe.running = true; }
    }

    Component.onCompleted: {
        devicesProbe.running = true;
        wallpaperProc.running = true;
        weatherProc.running = true; // the 60s timer alone would miss the first minute
    }

    // ── rounded-corner image helper (mask runs through MultiEffect) ────────
    component RoundedImage: Item {
        id: ri
        property alias source: img.source
        property alias imgStatus: img.status
        property real rounding: 0
        Image {
            id: img
            visible: false // rendered only through the mask MultiEffect
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            maskEnabled: true
            maskSource: maskItem
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        // kept offscreen: it must render (mask texture) but never paint in view
        Item {
            id: maskItem
            x: -3000
            y: -3000
            width: ri.width
            height: ri.height
            Rectangle {
                anchors.fill: parent
                radius: ri.rounding
                color: "white"
            }
        }
    }

    // Soft white glow behind dark palette text so it stays readable on any
    // wallpaper. MultiEffect does NOT hide its source (Qt docs: you must set
    // visible:false yourself — the effect still samples it), so every Glow
    // source below is a visible:false Text and the effect IS the rendering.
    // The item is grown symmetrically (paddingRect) so the shadow is not
    // clipped; autoPadding off keeps geometry fully deterministic.
    component Glow: MultiEffect {
        x: source.x - 24
        y: source.y - 24
        width: source.width + 48
        height: source.height + 48
        autoPaddingEnabled: false
        paddingRect: Qt.rect(24, 24, 24, 24)
        shadowEnabled: true
        shadowBlur: 0.4
        shadowColor: "#ffffff"
        shadowOpacity: 0.7
        shadowVerticalOffset: 1
    }

    // ═══════════════════════════ the lock screen content ═══════════════════
    Component {
        id: lockContent

        Item {
            id: c
            anchors.fill: parent
            focus: true
            opacity: 0

            function playFade() { fadeAnim.restart(); }

            NumberAnimation {
                id: fadeAnim
                target: c
                property: "opacity"
                from: 0; to: 1
                duration: 280
                easing.type: Easing.OutCubic
            }
            Component.onCompleted: fadeAnim.restart()

            Keys.onPressed: event => root.handleKey(event)

            // ── background: blurred current wallpaper ─────────────────────
            Rectangle { anchors.fill: parent; color: "#000000" }
            Image {
                id: wall
                visible: false // rendered only through the blur MultiEffect
                anchors.fill: parent
                anchors.margins: -64 // blur samples transparent padding at edges
                source: "file://" + root.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.max(128, Math.round((c.width + 128) / 128) * 128)
                sourceSize.height: 0
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blurMax: 64
                blur: 1.0
            }

            // ── clock + date ──────────────────────────────────────────────
            // the grabbed source (timeBlock) is visible:false — its Glow
            // effect is the rendering; the Text children stay visible so they
            // land in the effect's texture (nested visible:false would not)
            Item {
                id: timeBlock
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.13)
                width: bigTime.width + 10 + apTime.width
                height: bigTime.height

                Text {
                    id: bigTime
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.timeText
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 64
                }
                Text {
                    id: apTime
                    x: bigTime.width + 10
                    anchors.baseline: bigTime.baseline
                    text: root.ampmText
                    color: Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                }
            }
            Glow { source: timeBlock }
            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: timeBlock.bottom
                anchors.topMargin: 8
                visible: false
                // date +"%A, %B %d"
                text: Qt.formatDate(root.now, "dddd, MMMM dd")
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 19
            }
            Glow { source: dateLabel }

            // ── profile photo [hyprlock "Profile-Photo" block] ────────────
            // hidden until the image exists; point profilePhotoPath elsewhere
            // or drop the file into ~/Pictures/wallpapers/ to show it
            RoundedImage {
                id: photo
                anchors.centerIn: parent
                width: 150
                height: 150
                rounding: 75
                visible: imgStatus === Image.Ready
                source: root.profilePhotoPath
            }
            Rectangle {
                visible: photo.visible
                anchors.centerIn: photo
                width: photo.width
                height: photo.height
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: "#1b1d1f"
            }

            // ── password field ────────────────────────────────────────────
            // outer ring = state gradient (conf check_color / fail_color),
            // inner = the rice pill; idle state is inner-only
            Rectangle {
                id: fieldOuter
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 160
                width: 244
                height: 54
                radius: 27
                visible: root.effState === "checking" || root.effState === "failed"
                gradient: root.effState === "failed"
                    ? failGrad : checkGrad
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            Gradient {
                id: checkGrad
                GradientStop { position: 0.0; color: Theme.accent }
                GradientStop { position: 1.0; color: Theme.urgent }
            }
            Gradient {
                id: failGrad
                GradientStop { position: 0.0; color: Theme.urgent }
                GradientStop { position: 1.0; color: Theme.danger }
            }
            // the field itself is invisible (hyprlock parity: transparent
            // fill and outline) — only the dots show, blended into the
            // wallpaper via their glow; the gradient ring appears on states
            Item {
                id: field
                visible: false
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 160
                width: 240
                height: 50

                // dots (default) / asterisks (dots_text_format) / single
                // indicator (hide_input) — exactly one is visible
                Row {
                    anchors.centerIn: parent
                    spacing: 9
                    visible: !root.hideInput && !root.asteriskDots

                    Repeater {
                        model: Math.min(root.effBuffer.length, 12)
                        Rectangle {
                            required property int index
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.fg
                            opacity: 0.85
                            // inputFieldDots parity: the newest dot breathes
                            SequentialAnimation on opacity {
                                running: index === root.effBuffer.length - 1
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { to: 0.35; duration: 600 }
                                NumberAnimation { to: 0.85; duration: 600 }
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.asteriskDots && !root.hideInput
                    text: "*".repeat(Math.min(root.effBuffer.length, 12))
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    font.letterSpacing: 6
                }
                NIcon {
                    anchors.centerIn: parent
                    visible: root.hideInput
                    name: "lock"
                    iconSize: 18
                    iconColor: Theme.fg
                }
            }
            Glow { source: field; shadowOpacity: 1.0; shadowBlur: 0.6 }

            // sources visible:false; the EFFECT's visible is the real switch
            // (a hidden source still renders through its MultiEffect)
            Text {
                id: capsLabel
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: field.bottom
                anchors.topMargin: 10
                text: "Caps Lock active"
                color: Theme.urgent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
            Glow { source: capsLabel; visible: root.capsActive }

            Text {
                id: failLabel
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: capsLabel.bottom
                anchors.topMargin: 10
                text: root.failMessage !== "" ? root.failMessage : "Wrong password"
                color: root.effState === "error" ? Theme.urgent : Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
            Glow {
                source: failLabel
                visible: root.effState === "failed" || root.effState === "error"
            }

            // ── right column: battery [+ chip], weather, status ───────────
            // each block anchors to the SCREEN edge directly (a Column +
            // child right-anchors made the texts overflow off-screen); the
            // sources are visible:false — their Glows render them
            Item {
                id: battBlock
                visible: false
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 30
                anchors.topMargin: 28
                width: battRow.width + 28
                height: battRow.height + 18

                // Battery-div chip [hyprlock commented shape block] —
                // comment out this Rectangle to keep a bare battery label
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: Theme.pillBg
                    border.width: 1
                    border.color: Theme.border
                }
                Row {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batt ? Math.round(root.batt.percentage * 100) + "%" : ""
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                    }
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.battCharging ? "batteryCharging" : "battery"
                        level: root.batt ? root.batt.percentage : 0
                        iconSize: 22
                        iconColor: Theme.fg
                    }
                }
            }
            Glow { source: battBlock; visible: root.battVisible }

            Text {
                id: weatherLabel
                visible: false
                anchors.right: parent.right
                anchors.top: battBlock.bottom
                anchors.rightMargin: 30
                anchors.topMargin: 12
                text: root.weatherText
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }
            Glow { source: weatherLabel; visible: root.weatherText !== "" }

            Text {
                id: statusLabel
                visible: false
                anchors.right: parent.right
                anchors.top: weatherLabel.bottom
                anchors.rightMargin: 30
                anchors.topMargin: 10
                text: root.statusText
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
            Glow { source: statusLabel }

            // ── media widget [hyprlock commented media widget] ────────────
            // no card background — it blends into the wallpaper; the whole
            // row is an opacity:0 grab rendered by one Glow. opacity (not
            // visible) keeps the transport buttons clickable per the Qt docs
            // ("the source item is completely transparent, but still can
            // receive touch or click input")
            Row {
                id: mediaRow
                opacity: 0
                visible: root.mediaPlayer !== null
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 88
                spacing: 18

                Item {
                    width: 100
                    height: 100
                    readonly property bool hasArt: root.mediaPlayer && root.mediaPlayer.trackArtUrl !== ""
                    RoundedImage {
                        anchors.fill: parent
                        rounding: 15
                        visible: parent.hasArt
                        source: root.mediaPlayer ? root.mediaPlayer.trackArtUrl : ""
                    }
                    NIcon {
                        anchors.centerIn: parent
                        visible: !parent.hasArt
                        name: "music"
                        iconSize: 40
                        iconColor: Theme.fg
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.border
                        visible: parent.hasArt
                    }
                }

                Column {
                    width: 220
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.mediaPlayer ? root.mediaPlayer.trackTitle : ""
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: root.mediaPlayer ? root.mediaPlayer.trackArtists : ""
                        elide: Text.ElideRight
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    Row {
                        spacing: 26

                        Repeater {
                            model: [
                                { icon: "prev",  size: 18, act: "prev" },
                                { icon: root.mediaPlayer && root.mediaPlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play", size: 22, act: "toggle" },
                                { icon: "next",  size: 18, act: "next" }
                            ]
                            delegate: Item {
                                id: mbtn
                                required property var modelData
                                width: modelData.size + 8
                                height: modelData.size + 8
                                opacity: mbtnHover.hovered ? 1 : 0.7
                                NIcon {
                                    anchors.centerIn: parent
                                    name: mbtn.modelData.icon
                                    iconSize: mbtn.modelData.size
                                    iconColor: Theme.fg
                                }
                                HoverHandler { id: mbtnHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        const p = root.mediaPlayer;
                                        if (!p) return;
                                        if (mbtn.modelData.act === "prev" && p.canGoPrevious) p.previous();
                                        else if (mbtn.modelData.act === "next" && p.canGoNext) p.next();
                                        else if (mbtn.modelData.act === "toggle" && p.canTogglePlaying) p.togglePlaying();
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Glow { source: mediaRow; visible: root.mediaPlayer !== null }

            // ── keyboard layout switcher [hyprlock commented $LAYOUT] ─────
            // plain glowing text (no pill background); the opacity:0 grab
            // keeps hover/click working while the Glow renders it
            Item {
                id: kbdArea
                opacity: 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 24
                anchors.bottomMargin: 20
                width: kbdLabel.width + 24
                height: 30

                Text {
                    id: kbdLabel
                    anchors.centerIn: parent
                    text: root.kbdLayoutShort
                    color: kbdHover.hovered ? Theme.urgent : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
                HoverHandler { id: kbdHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: layoutSwitch.running = true }
            }
            Glow { source: kbdArea; visible: root.kbdLayout !== "" }

            Text {
                visible: root.testMode
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.bottomMargin: 20
                text: "lockscreen preview — type, Enter simulates a wrong password, Esc closes"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }
}
