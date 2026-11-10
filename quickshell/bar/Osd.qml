import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../core"
import "../ui"

// On-screen display for volume / microphone / brightness — a visual port of
// end-4's ii shell OsdValueIndicator, driven directly by the services (NOT by
// notifications): Pipewire for volume/mic, the backlight sysfs polled for
// brightness. Sits on the Overlay layer so it shows above the dashboard
// popup, and hides 1s after the last change (timer restarts on every new
// trigger, so holding a key keeps it up).
PanelWindow {
    id: root

    property bool open: false
    // which indicator is showing: "volume" | "mic" | "brightness"
    property string current: "volume"
    // bar value, 0..1 (volume above 100% still fills the bar; displayValue
    // carries the real number)
    property real value: 0
    property real displayValue: 0
    property bool muted: false

    // ignore service events for the first second after launch (the Pipewire
    // tracker fires initial property updates on attach — that must not pop
    // the OSD at startup)
    property bool armed: false

    // lets Toast shift down below the OSD while it is showing
    onOpenChanged: Notifs.osdShowing = open

    anchors {
        top: true
        right: true
    }
    implicitWidth: 200
    implicitHeight: 52
    margins.right: 10
    margins.top: Theme.barHeight + 8
    // must ignore exclusive zones, same as the other top-right surfaces
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: -1
    color: "transparent"
    visible: open
    // Overlay: above the dashboard's Top-layer shield — the OSD shows even
    // while the popup is open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"

    Component.onCompleted: {
        armTimer.start();
        backlightProbe.running = true;
    }

    Timer {
        id: armTimer
        interval: 1000
        onTriggered: root.armed = true
    }

    function trigger(kind) {
        if (!root.armed) return;
        root.current = kind;
        root.open = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.open = false
    }

    readonly property string osdIcon: {
        if (current === "volume")
            return muted ? "volumeMuted" : (displayValue < 0.5 ? "volumeLow" : "volumeHigh");
        if (current === "mic")
            return muted ? "micOff" : "mic";
        if (current === "brightness")
            return "brightness";
        return "bell";
    }
    readonly property string osdName: current === "volume" ? "Volume"
        : current === "mic" ? "Microphone" : "Brightness"
    readonly property int displayNumber: Math.round(displayValue * 100)

    // ── volume + mic (Pipewire) ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() {
            const a = Pipewire.defaultAudioSink?.audio;
            if (!a) return;
            if (a.volume > 1.0) {
                // hard cap at 100% — writes fire another volumeChanged that
                // drives the UI from here
                a.volume = 1.0;
                return;
            }
            root.muted = a.muted;
            root.displayValue = a.volume;
            root.value = Math.min(1, a.volume);
            root.trigger("volume");
        }
        function onMutedChanged() {
            const a = Pipewire.defaultAudioSink?.audio;
            if (!a) return;
            root.muted = a.muted;
            root.displayValue = a.volume;
            root.value = Math.min(1, a.volume);
            root.trigger("volume");
        }
    }

    Connections {
        target: Pipewire.defaultAudioSource?.audio ?? null
        function onMutedChanged() {
            if (!Pipewire.defaultAudioSource?.audio) return;
            root.muted = Pipewire.defaultAudioSource.audio.muted;
            root.value = root.muted ? 0 : 1;
            root.displayValue = root.value;
            root.trigger("mic");
        }
    }

    // ── brightness (backlight sysfs; kernfs emits no inotify events, so poll)
    property string backlightDevice: ""
    property int maxBrightness: 0
    property real lastSeenBrightness: -1

    Process {
        id: backlightProbe
        command: ["sh", "-c", "ls -1 /sys/class/backlight | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlightDevice = text.trim()
        }
    }

    FileView {
        id: maxView
        path: root.backlightDevice === ""
            ? "" : "/sys/class/backlight/" + root.backlightDevice + "/max_brightness"
        onLoaded: root.maxBrightness = parseInt(text())
    }
    FileView {
        id: brightView
        path: root.backlightDevice === ""
            ? "" : "/sys/class/backlight/" + root.backlightDevice + "/brightness"
        onLoaded: {
            const raw = parseInt(text());
            if (isNaN(raw) || root.maxBrightness <= 0) return;
            const frac = raw / root.maxBrightness;
            if (root.lastSeenBrightness < 0) {
                root.lastSeenBrightness = frac; // first read only calibrates
                return;
            }
            if (frac === root.lastSeenBrightness) return;
            root.lastSeenBrightness = frac;
            root.muted = false;
            root.displayValue = frac;
            root.value = Math.min(1, frac);
            root.speedUpPoll();
            root.trigger("brightness");
        }
    }
    Timer {
        id: pollTimer
        // 400ms steady-state baseline; speedUpPoll() below bursts it to 60ms
        // while a change is being tracked (see pollBurst)
        interval: 400
        running: root.backlightDevice !== ""
        repeat: true
        onTriggered: brightView.reload()
    }
    // adaptive rate: 60ms for ~1.5s after a detected change (feels instant
    // during key holds, like the volume path), then back to the 400ms baseline
    Timer {
        id: pollBurst
        interval: 1500
        onTriggered: pollTimer.interval = 400
    }
    function speedUpPoll() {
        pollTimer.interval = 60;
        pollBurst.restart();
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.border

        NIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: root.osdIcon
            iconSize: 22
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.osdName
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.displayNumber
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
            }

            Rectangle {
                id: barTrack
                width: parent.width
                height: 6
                radius: 3
                color: Theme.track

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 3
                    width: parent.width * root.value
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
