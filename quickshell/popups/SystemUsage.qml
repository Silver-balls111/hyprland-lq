import QtQuick
import Quickshell.Io
import "../core"
import "../ui"

// Profile section at the bottom of the dashboard's calendar column — a
// fastfetch-style block (reference: user's screenshot): circular avatar left,
// distro / screen-time / uptime rows right, then the CPU / Memory / Disk bar
// rows below. No card background — the content blends into the popup like
// the rest of the dashboard. DashPopup anchors this section below the
// calendar's worst-case (6-row) footprint and stretches it to the column
// bottom. Quickshell 0.3.1 has no
// system-info service, so everything is polled the same way the OSD polls
// the backlight: FileView.reload() driven by a timer (procfs/sysfs emit no
// inotify events, so watchChanges is useless). Polling only runs while the
// dashboard is open — DashPopup calls start()/stop(). Screen time comes from
// the ScreenTime singleton, which accumulates all day regardless.
Item {
    id: root

    // ── live display state (written by the parsers below) ──
    property real cpuFraction: 0
    property string cpuTempText: "" // "53°C", empty until first read
    property real memFraction: 0
    property string memText: "" // "9.4 / 15.0 GiB"
    property real diskFraction: 0
    property string diskText: ""
    property string uptimeText: "" // "up 10 hours, 6 minutes"
    property string screenText: "" // "2h 14m" (compact — parallels the
    // short "Hyprland" row of the reference card)
    property string distroName: ""
    property string distroGlyphName: "linux"

    // CPU delta baseline — the first /proc/stat read after start() only
    // calibrates (same `armed` idea as the OSD's first brightness read)
    property real prevCpuTotal: -1
    property real prevCpuIdle: -1
    // seconds since epoch of boot, resolved once per open from /proc/uptime
    property real bootEpoch: 0
    property string tempPath: ""

    readonly property int pollMs: 2000

    // ── layout: blended (no card background — sits directly on popupBg like
    // the rest of the dashboard). DashPopup anchors this section below the
    // calendar's worst-case (6-row) footprint and stretches it to the column
    // bottom; leftover height is distributed evenly between the profile block
    // and the three bar rows.
    readonly property real profileH: 70 // matches the 70px avatar exactly
    readonly property real statH: 28 // label row 18 + 4 + bar 6
    readonly property real gap: Math.max(10, (height - profileH - 3 * statH) / 3)

    function start() {
        prevCpuTotal = -1;
        prevCpuIdle = -1;
        dfProc.running = true;
        if (tempPath === "")
            tempProbe.running = true; // single flight — path never changes while running
        osView.reload();
        uptimeView.reload();
        statView.reload();
        memView.reload();
        if (tempPath !== "")
            tempView.reload();
        root.tick(); // screen time + uptime text right away (first poll is 2s out)
        pollTimer.restart();
    }

    function stop() {
        pollTimer.stop();
    }

    function tick() {
        if (bootEpoch > 0)
            uptimeText = "up " + fmtDurLong(Date.now() / 1000 - bootEpoch);
        screenText = fmtDur(ScreenTime.awakeSeconds());
    }

    // compact: "42m" / "3h 24m" / "5d 3h" (screen time row)
    function fmtDur(sec) {
        if (isNaN(sec) || sec < 0) return "—";
        if (sec < 3600) return Math.max(0, Math.floor(sec / 60)) + "m";
        if (sec < 86400) {
            const h = Math.floor(sec / 3600);
            const m = Math.floor((sec % 3600) / 60);
            return h + "h " + m + "m";
        }
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        return d + "d " + h + "h";
    }

    // verbose, fastfetch-style: "1 hour, 23 minutes" (uptime row; the "up "
    // prefix is added by tick())
    function fmtDurLong(sec) {
        if (isNaN(sec) || sec < 0) return "—";
        if (sec < 3600) {
            const m = Math.max(0, Math.floor(sec / 60));
            return m + (m === 1 ? " minute" : " minutes");
        }
        if (sec < 86400) {
            const h = Math.floor(sec / 3600);
            const m = Math.floor((sec % 3600) / 60);
            return h + (h === 1 ? " hour, " : " hours, ") + m + (m === 1 ? " minute" : " minutes");
        }
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        return d + (d === 1 ? " day, " : " days, ") + h + (h === 1 ? " hour" : " hours");
    }

    // KiB (the unit /proc/meminfo calls "kB") → "9.4 GiB"
    function fmtGiB(kib) {
        const gib = kib / 1048576;
        return (gib >= 100 ? Math.round(gib) : Math.round(gib * 10) / 10) + " GiB";
    }

    // ── data sources ──

    // distro name for the card row — read from /etc/os-release (NOT
    // hardcoded) so the rice travels between systems
    FileView {
        id: osView
        path: "/etc/os-release"
        onLoaded: {
            let pretty = "", name = "";
            const lines = text().split("\n");
            for (let i = 0; i < lines.length; i++) {
                if (pretty === "" && lines[i].startsWith("PRETTY_NAME="))
                    pretty = lines[i].slice(12).replace(/^"|"$/g, "");
                else if (name === "" && lines[i].startsWith("NAME="))
                    name = lines[i].slice(5).replace(/^"|"$/g, "");
                if (pretty !== "" && name !== "") break;
            }
            const distro = pretty !== "" ? pretty : (name !== "" ? name : "Linux");
            root.distroName = distro;
            // glyph match on the lowercased name; Icons has the nerd-font
            // distro set, "linux" (penguin) is the fallback
            const lower = distro.toLowerCase();
            root.distroGlyphName = lower.includes("arch") ? "arch" : "linux";
        }
    }

    // CPU: aggregate "cpu  user nice system idle iowait irq softirq steal"
    // line; usage = 1 − Δidle/Δtotal between consecutive samples
    FileView {
        id: statView
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n", 1)[0].trim().split(/\s+/);
            if (f[0] !== "cpu" || f.length < 5) return;
            let total = 0;
            for (let i = 1; i <= 8 && i < f.length; i++)
                total += parseFloat(f[i]);
            const idle = parseFloat(f[4]) + parseFloat(f[5]); // idle + iowait
            if (isNaN(total) || isNaN(idle)) return;
            if (root.prevCpuTotal >= 0) {
                const dT = total - root.prevCpuTotal;
                const dI = idle - root.prevCpuIdle;
                if (dT > 0)
                    root.cpuFraction = Math.max(0, Math.min(1, 1 - dI / dT));
            }
            root.prevCpuTotal = total;
            root.prevCpuIdle = idle;
        }
    }

    FileView {
        id: memView
        path: "/proc/meminfo"
        onLoaded: {
            let total = -1, avail = -1;
            const lines = text().split("\n");
            for (let i = 0; i < lines.length; i++) {
                if (total < 0 && lines[i].startsWith("MemTotal:"))
                    total = parseInt(lines[i].slice(9));
                else if (avail < 0 && lines[i].startsWith("MemAvailable:"))
                    avail = parseInt(lines[i].slice(13));
                if (total >= 0 && avail >= 0) break;
            }
            if (total > 0 && avail >= 0) {
                // "available" (not "free") is what free(1)/htop count as used
                root.memFraction = Math.min(1, (total - avail) / total);
                root.memText = fmtGiB(total - avail) + " / " + fmtGiB(total);
            }
        }
    }

    FileView {
        id: uptimeView
        path: "/proc/uptime"
        onLoaded: {
            const up = parseFloat(text());
            if (!isNaN(up) && up > 0)
                root.bootEpoch = Date.now() / 1000 - up;
        }
    }

    FileView {
        id: tempView
        path: root.tempPath
        onLoaded: {
            const t = parseInt(text());
            if (!isNaN(t))
                root.cpuTempText = Math.round(t / 1000) + "°C";
        }
    }

    // total usage across the machine's real filesystems (single drive here:
    // / + /boot + /home sum via --total). Runs once per open — disk usage
    // doesn't move on poll timescales.
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=used,size", "--total",
            "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = lines.length - 1; i >= 0; i--) {
                    const f = lines[i].trim().split(/\s+/);
                    if (f.length === 2 && !isNaN(parseInt(f[0])) && parseInt(f[1]) > 0) {
                        const used = parseInt(f[0]);
                        const size = parseInt(f[1]);
                        root.diskFraction = Math.min(1, used / size);
                        root.diskText = fmtGiB(used / 1024) + " / " + fmtGiB(size / 1024);
                        return;
                    }
                }
            }
        }
    }

    // CPU temp sensor: prefer the CPU hwmon (k10temp on this AMD box,
    // coretemp/zenpower elsewhere), fall back to the acpi thermal zone
    Process {
        id: tempProbe
        command: ["sh", "-c",
            'for d in /sys/class/hwmon/hwmon*; do ' +
            'case "$(cat "$d/name" 2>/dev/null)" in ' +
            'k10temp|coretemp|zenpower) echo "$d/temp1_input"; exit 0;; esac; done; ' +
            'echo /sys/class/thermal/thermal_zone0/temp']
        stdout: StdioCollector {
            onStreamFinished: {
                root.tempPath = text.trim();
                if (root.tempPath !== "")
                    tempView.reload();
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollMs
        repeat: true
        onTriggered: {
            statView.reload();
            memView.reload();
            if (root.tempPath !== "")
                tempView.reload();
            root.tick();
        }
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.gap

        // profile: avatar + distro / screen time / uptime rows
        Item {
            width: parent.width
            height: root.profileH

            Rectangle {
                id: pfpFallback
                width: 70
                height: 70
                radius: 35
                color: Theme.inputBg
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: pfp.imgStatus !== Image.Ready
                NIcon {
                    anchors.centerIn: parent
                    name: root.distroGlyphName
                    iconSize: 24
                    iconColor: Theme.fgMuted
                }
            }
            RoundedImage {
                id: pfp
                anchors.fill: pfpFallback
                rounding: 28
                // repo-relative (resolved against THIS file's dir) — the
                // rice stays portable; replace assets/pfp.png to change it
                source: Qt.resolvedUrl("../assets/pfp.png")
            }

            Column {
                anchors.left: pfpFallback.right
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                InfoRow {
                    width: parent.width
                    glyphName: root.distroGlyphName
                    text: root.distroName === "" ? "Linux" : root.distroName
                }
                InfoRow {
                    width: parent.width
                    glyphName: "monitor"
                    text: root.screenText
                }
                InfoRow {
                    width: parent.width
                    glyphName: "clock"
                    text: root.uptimeText
                }
            }
        }

        StatBlock {
            width: parent.width
            iconName: "cpu"
            label: "CPU"
            valueText: Math.round(root.cpuFraction * 100) + "%"
            subText: root.cpuTempText === "" ? "" : " · " + root.cpuTempText
            fraction: root.cpuFraction
        }

        StatBlock {
            width: parent.width
            iconName: "memory"
            label: "Memory"
            valueText: root.memText
            fraction: root.memFraction
        }

        StatBlock {
            width: parent.width
            iconName: "disk"
            label: "Disk"
            valueText: root.diskText
            fraction: root.diskFraction
        }
    }

    // glyph + value row of the profile part (labels omitted, like the
    // reference card — the glyph carries the meaning)
    component InfoRow: Row {
        id: ir
        property string glyphName: ""
        property string text: ""
        spacing: 8
        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: ir.glyphName
            iconSize: 15
            iconColor: Theme.fgMuted
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ir.text
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            elide: Text.ElideRight
        }
    }

    // one label row + one slim bar (visual copied from the OSD's bar)
    component StatBlock: Item {
        id: blk
        property string iconName: ""
        property string label: ""
        property string valueText: ""
        property string subText: ""
        property real fraction: 0
        height: inner.implicitHeight
        Column {
            id: inner
            width: parent.width
            spacing: 4
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: blk.iconName
                        iconSize: 15
                        iconColor: Theme.fgMuted
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: blk.label
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: blk.valueText
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: blk.subText
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.track
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 3
                    width: parent.width * Math.max(0, Math.min(1, blk.fraction))
                    color: Theme.accent
                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
