pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Cumulative "screen time today" accumulator for the dashboard's system usage
// section. "Screen off" mirrors the user's hypridle DPMS listener: the same
// ext-idle-notify protocol with the same 330s timeout and inhibitors
// respected, so isIdle tracks the real screen state closely (backlight dims
// at 300s, dpms-off fires at 330s, suspend at 600s still counts as off).
//
// Lives as a singleton because it must accumulate all day even when the
// dashboard is never opened (DashPopup/SystemUsage exist per screen, and only
// one popup can be open at a time). State persists to a cache sidecar
// ("<yyyy-MM-dd> <seconds>") so bar restarts don't lose the count; the day
// resets lazily on the first read/write past midnight. An awake stretch that
// spans midnight counts entirely into the new day (documented simplification).
// NB: root is an Item, NOT a QtObject — a QtObject root cannot host children
// ("Cannot assign to non-existent default property").
Item {
    id: root

    // seconds of inactivity that count as "screen off" — non-readonly so a
    // throwaway test instance can shorten it
    property int idleTimeoutSec: 330

    property string dayKey: ""
    property real accumulated: 0 // seconds banked by closed awake stretches
    property real awakeSince: -1 // ms epoch of the open stretch, -1 while idle

    property bool initialized: false

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell_rice"
    readonly property string sidecarPath: cacheDir + "/screen-time"

    function todayKey() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    // lazy midnight rollover — called from every read/write path
    function rolloverCheck() {
        const tk = todayKey();
        if (dayKey !== tk) {
            dayKey = tk;
            accumulated = 0;
        }
    }

    function awakeSeconds() {
        rolloverCheck();
        return accumulated + (awakeSince > 0 ? (Date.now() - awakeSince) / 1000 : 0);
    }

    // called once from shell.qml's Component.onCompleted so the singleton
    // materializes (and starts counting) at session start
    function init() {
        if (initialized) return;
        initialized = true;
        dayKey = todayKey();
        // assume awake until the monitor flips — IdleMonitor starts non-idle
        awakeSince = Date.now();
        reader.running = true;
    }

    // sidecar I/O via Process, not FileView: a missing file is the normal
    // first-run state and FileView's failed-load callback timing is exactly
    // the kind of ambiguity that once reverted a pin sidecar race-style
    Process {
        id: reader
        command: ["sh", "-c",
            'mkdir -p "$(dirname "$1")"; [ -f "$1" ] && cat "$1" || true',
            "sh", root.sidecarPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^(\d{4}-\d{2}-\d{2}) (\d+)$/);
                if (m && m[1] === root.dayKey)
                    root.accumulated = parseInt(m[2]);
            }
        }
    }

    Process {
        id: writer
        command: []
    }
    property string writePayload: ""

    function write() {
        rolloverCheck();
        // bank the open stretch too, so a crash loses at most nothing and a
        // reload mid-stretch resumes from the write (awakeSince stays put —
        // the next idle flip re-banks it from the original wake time)
        writePayload = Math.round(awakeSeconds()) + "";
        writer.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s %s\\n" "$1" "$3" > "$2"',
            "sh", dayKey, root.sidecarPath, writePayload];
        writer.running = true;
    }

    IdleMonitor {
        id: monitor
        timeout: root.idleTimeoutSec
        respectInhibitors: true
        onIsIdleChanged: {
            if (monitor.isIdle) {
                if (root.awakeSince > 0) {
                    root.accumulated += (Date.now() - root.awakeSince) / 1000;
                    root.awakeSince = -1;
                }
            } else {
                root.awakeSince = Date.now();
            }
            root.write();
        }
    }

    // checkpoint: survives a bar crash/upgrade mid-stretch, and persists the
    // midnight rollover even on a day with no idle flips at all
    Timer {
        interval: 300000 // 5 min
        running: true
        repeat: true
        onTriggered: root.write()
    }
}
