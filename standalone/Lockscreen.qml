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
import "../core"
import "../ui"

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
    // hyprlock parity: "animation = fadeIn, 1, 5, linear" — the speed param
    // is DECISECONDS (hyprutils getPercent: duration = 100 × speed ms), so
    // 5 → 500ms with the linear bezier. Set 5000 only if you want it 10×
    // slower than hyprlock ever was. The fade-out still runs BEFORE the
    // lock is released (compositor-side layer rules can't animate a surface
    // that is already destroyed)
    property int lockFadeInMs: 600
    property int lockFadeOutMs: 700
    property bool unlocking: false
    // repo-relative (Qt.resolvedUrl anchors it to THIS file's location) so the
    // rice is portable — no ~/Pictures dependency; drop any square-ish image
    // at <repo>/assets/pfp.png to replace the placeholder
    property string profilePhotoPath: Qt.resolvedUrl("../assets/pfp.png")
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

    // ── adaptive text colors (readability on any wallpaper) ───────────────
    // the wallpaper's average luminance is sampled once per lock (see
    // lumSampler in the content); dark wallpapers get light text, light
    // wallpapers keep the dark palette fg — no shadows, no cards (user spec)
    property bool wallDark: false
    readonly property color lockFg: wallDark ? "#f2f2f2" : Theme.fg
    readonly property color lockFgMuted: wallDark ? Qt.rgba(1, 1, 1, 0.62) : Theme.fgMuted

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
        unlocking = false;
        buffer = "";
        authState = "idle";
        failMessage = "";
        pendingSubmit = false;
        pamBroken = false;
        pamRetried = false;
        wallpaperProc.running = true;
        // weatherProc.running = true; // weather widget disabled
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
        if (!LockState.engaged || unlocking) return;
        // fade the lock content out first; finishUnlock releases the session
        // once the surface is actually faded (hyprlock fadeOut parity)
        unlocking = true;
        unlockFiniTimer.restart();
    }

    Timer {
        id: unlockFiniTimer
        interval: root.lockFadeOutMs
        onTriggered: root.finishUnlock()
    }

    function finishUnlock() {
        LockState.engaged = false;
        unlocking = false;
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
            // the failure text is ALWAYS "Authentication failed" — whatever
            // pam_unix put in .message goes to the log only
            console.warn("lockscreen: PAM failure message:", pam.message);
            root.failMessage = "";
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
            root.failMessage = "Authentication failed (simulated)";
            root.buffer = "";
            failResetTimer.restart();
        }
    }

    function handleKey(event) {
        if (root.unlocking) { event.accepted = true; return; }
        const k = event.key;
        if (k === Qt.Key_CapsLock) {
            event.accepted = true;
            if (!devicesProbe.running) devicesProbe.running = true; // fresh state right now
            return;
        }
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
                    if (main && main.capsLock !== undefined)
                        root.capsOn = main.capsLock === true; // missing field = keep last state
                    if (main) root.kbdLayout = main.active_keymap || "";
                } catch (e) {
                    console.warn("lockscreen: hyprctl devices parse failed:", e);
                }
            }
        }
    }
    // capsLock label poll; the same probe feeds the keyboard-layout label.
    // Single-flight (never spawn while one is in flight) — overlapping
    // results could land out of order and resurrect a stale caps state.
    // Re-probed immediately on CapsLock keypresses (see handleKey).
    Timer {
        id: devicesTimer
        interval: 1000
        repeat: true
        running: LockState.engaged || root.testMode
        onTriggered: if (!devicesProbe.running) devicesProbe.running = true
    }

    // weather poll + keyboard-layout switch — DISABLED with their widgets
    // (uncomment together with the weather/status/kbd blocks below)
    /*
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
    */

    Component.onCompleted: {
        devicesProbe.running = true;
        wallpaperProc.running = true;
        // weatherProc.running = true; // weather widget disabled
    }

    // NOTE: no text shadows/glows anywhere — the user rejected the soft
    // white halo ("weird effect"); every text renders plain over the blur.

    // ═══════════════════════════ the lock screen content ═══════════════════
    Component {
        id: lockContent

        Item {
            id: c
            anchors.fill: parent
            focus: true

            function playFade() { fadeAnim.restart(); }

            NumberAnimation {
                id: fadeAnim
                target: uiFade
                property: "opacity"
                from: 0; to: 1
                duration: root.lockFadeInMs
                easing.type: Easing.Linear // hyprlock: bezier "linear"
            }
            NumberAnimation {
                id: fadeOutAnim
                target: uiFade
                property: "opacity"
                to: 0
                duration: root.lockFadeOutMs
                easing.type: Easing.Linear
            }
            Component.onCompleted: fadeAnim.restart()
            Connections {
                target: root
                function onUnlockingChanged() {
                    if (root.unlocking) fadeOutAnim.restart();
                }
            }

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

            // samples the wallpaper's average luminance once per load and
            // flips root.wallDark, which drives lockFg/lockFgMuted above.
            // THREE lifecycle traps (all hit): getContext() needs the canvas
            // to be `available`, which is false during construction (real
            // bar: content is created with the path already set → the
            // sampled decode must wait for availability); in preview the
            // path arrives late, so the load must also trigger from
            // onWallUrlChanged; and a sample taken BEFORE the decode finished
            // reads all-transparent pixels, whose 0-luminance would classify
            // the wallpaper as dark FOREVER (one-way to true) — hence the
            // zero-coverage retry below.
            Canvas {
                id: lumSampler
                visible: false
                width: 16
                height: 9
                readonly property string wallUrl: root.wallpaperPath !== ""
                    ? "file://" + root.wallpaperPath : ""
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
                // canvas became usable while the decode was still pending —
                // re-issue the load so onImageLoaded fires with it
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
                        // nothing decoded into the canvas yet — retry a few
                        // times; if the wallpaper is genuinely unloadable the
                        // background is the black backing, so bright text
                        // (wallDark = true) is the correct fallback anyway
                        if (retries < 5) {
                            retries++;
                            retryTimer.restart();
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
                    id: retryTimer
                    interval: 250
                    onTriggered: lumSampler.sample()
                }
            }

            // all UI overlays fade in/out TOGETHER inside this wrapper, while
            // the wallpaper below stays opaque — fading the whole content
            // flashed the surface's black backing mid-fade (hyprlock never
            // dips to black: its wallpaper is opaque from the first frame)
            Item {
                id: uiFade
                anchors.fill: parent
                opacity: 0

            // ── clock + date ──────────────────────────────────────────────
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
                // date +"%A, %B %d"
                text: Qt.formatDate(root.now, "dddd, MMMM dd")
                color: root.lockFgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 22
            }

            // ── profile photo [hyprlock "Profile-Photo" block] ────────────
            // points at the repo asset ../assets/pfp.png — replace that file
            // to change the picture. (This block stays ACTIVE until the user
            // confirms everything works, then gets commented out.)
            RoundedImage {
                id: photo
                anchors.centerIn: parent
                width: 150
                height: 150
                rounding: 75
                visible: imgStatus === Image.Ready
                source: root.profilePhotoPath
            }

            // ── password field ────────────────────────────────────────────
            // the field itself is invisible (hyprlock parity: transparent
            // fill and outline) — only the dots show. On FAIL a thin
            // gradient border highlights the outline ONCE and fades away
            // (no ring while verifying, no looping animation — user spec).
            // Canvas because a Rectangle's border cannot take a gradient.
            Canvas {
                id: fieldRing
                anchors.centerIn: field // follows the field wherever it sits
                width: 248
                height: 58
                visible: root.effState === "failed"
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.lineWidth = 2;
                    // hyprlock fail_color: rgba(ff6633ee) rgba(ff0066ee) 40deg
                    const theta = 40 * Math.PI / 180;
                    const dx = Math.sin(theta), dy = -Math.cos(theta);
                    const cx = width / 2, cy = height / 2;
                    const len = Math.abs(width * dx) + Math.abs(height * dy);
                    const grad = ctx.createLinearGradient(
                        cx - dx * len / 2, cy - dy * len / 2,
                        cx + dx * len / 2, cy + dy * len / 2);
                    grad.addColorStop(0, "rgba(255,102,51,0.93)");
                    grad.addColorStop(1, "rgba(255,0,102,0.93)");
                    ctx.strokeStyle = grad;
                    const x = 1, y = 1, w = width - 2, h = height - 2, r = 27;
                    ctx.beginPath();
                    ctx.moveTo(x + r, y);
                    ctx.lineTo(x + w - r, y);
                    ctx.arcTo(x + w, y, x + w, y + r, r);
                    ctx.lineTo(x + w, y + h - r);
                    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                    ctx.lineTo(x + r, y + h);
                    ctx.arcTo(x, y + h, x, y + h - r, r);
                    ctx.lineTo(x, y + r);
                    ctx.arcTo(x, y, x + r, y, r);
                    ctx.closePath();
                    ctx.stroke();
                }
                // show once at full strength, then fade out
                onVisibleChanged: {
                    if (visible) {
                        requestPaint();
                        ringFade.restart();
                    } else {
                        opacity = 1; // re-arm for the next failure
                    }
                }
                NumberAnimation {
                    id: ringFade
                    target: fieldRing
                    property: "opacity"
                    from: 1; to: 0
                    duration: 1800
                    easing.type: Easing.OutQuad
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: root
                    function onEffStateChanged() { fieldRing.requestPaint(); }
                }
            }
            Item {
                id: field
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 155
                width: 240
                height: 50

                // dots (default) / asterisks (dots_text_format) / single
                // indicator (hide_input) — exactly one is visible
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    visible: !root.hideInput && !root.asteriskDots

                    Repeater {
                        model: Math.min(root.effBuffer.length, 12)
                        Rectangle {
                            required property int index
                            width: 10
                            height: 10
                            radius: 5
                            color: root.lockFgMuted
                            opacity: 0.9
                            // inputFieldDots parity: the newest dot breathes
                            // no need for any kind of breathing animation
                            // SequentialAnimation on opacity {
                            //     running: index === root.effBuffer.length - 1
                            //     loops: Animation.Infinite
                            //     alwaysRunToEnd: true
                            //     NumberAnimation { to: 0.35; duration: 600 }
                            //     NumberAnimation { to: 0.9; duration: 600 }
                            // }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.asteriskDots && !root.hideInput
                    text: "*".repeat(Math.min(root.effBuffer.length, 12))
                    color: root.lockFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    font.letterSpacing: 6
                }
                NIcon {
                    anchors.centerIn: parent
                    visible: root.hideInput
                    name: "lock"
                    iconSize: 18
                    iconColor: root.lockFg
                }

                // failure message lives INSIDE the field (hyprlock fail_text
                // parity) — the buffer is cleared on failure so it replaces
                // the dots, and any new keypress (buffer non-empty) hides it
                Text {
                    anchors.centerIn: parent
                    visible: (root.effState === "failed" || root.effState === "error")
                             && root.effBuffer === ""
                    text: (root.effState === "error" && root.failMessage !== "")
                          ? root.failMessage : "Authentication failed"
                    color: root.effState === "error" ? Theme.urgent : Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            Text {
                id: capsLabel
                visible: root.capsActive
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: field.bottom
                anchors.topMargin: 12
                text: "Caps Lock active"
                color: Theme.urgent
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }

            // ── right column: battery, weather, status ────────────────────
            // each block anchors to the SCREEN edge directly with real gaps
            // (the user rejected both the chip background and the clamped
            // look). The old hyprlock "Battery-div" chip is kept commented:
            // Rectangle { radius: 18; color: Theme.pillBg; border.width: 1;
            //             border.color: Theme.border }  // behind the row
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
                    font.pixelSize: 20
                }
                NIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.battCharging ? "batteryCharging" : "battery"
                    level: root.batt ? root.batt.percentage : 0
                    iconSize: 22
                    iconColor: root.lockFgMuted
                }
            }

            // weather + status widgets — DISABLED by user (battery stays).
            // Re-enable by uncommenting; weatherText/statusText at the root
            // stay live either way.
            /*
            Text {
                id: weatherLabel
                visible: root.weatherText !== ""
                anchors.right: parent.right
                anchors.top: battRow.bottom
                anchors.rightMargin: 36
                anchors.topMargin: 20
                text: root.weatherText
                color: root.lockFgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }

            Text {
                id: statusLabel
                anchors.right: parent.right
                anchors.top: weatherLabel.bottom
                anchors.rightMargin: 36
                anchors.topMargin: 14
                text: root.statusText
                color: root.lockFgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
            */

            // ── media widget [hyprlock commented media widget] ────────────
            // no card background — it blends into the wallpaper
            Row {
                id: mediaRow
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
                        iconColor: root.lockFg
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
                        color: root.lockFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: root.mediaPlayer ? root.mediaPlayer.trackArtists : ""
                        elide: Text.ElideRight
                        color: root.lockFgMuted
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
                                    iconColor: root.lockFg
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

            // ── keyboard layout switcher [hyprlock commented $LAYOUT] ─────
            // DISABLED by user — uncomment to bring back (layoutSwitch
            // Process at the root is commented out with it)
            /*
            // plain text (no pill background)
            Item {
                id: kbdArea
                visible: root.kbdLayout !== ""
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
                    color: kbdHover.hovered ? Theme.urgent : root.lockFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
                HoverHandler { id: kbdHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: layoutSwitch.running = true }
            }
            */

            Text {
                visible: root.testMode
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.bottomMargin: 20
                text: "lockscreen preview — type, Enter simulates a wrong password, Esc closes"
                color: root.lockFgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            } // uiFade — end of the fading overlay stack
        }
    }
}
