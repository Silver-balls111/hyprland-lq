// Wallpaper picker — the skwd-wall "Slices" look, minus the feature buffet:
// a horizontal carousel of right-leaning sheared strips floating over the
// live desktop (NO dim backdrop — the window behind stays fully visible),
// with the selected wallpaper enlarged in the center at the SAME shear
// angle (one uniform lean across the whole row, accent border around it).
// Preview-first: click a strip / scroll / arrow keys to move the
// selection, then click the centered one or press Enter/Space to apply.
// Type to search: printable keys filter the set live (chip appears above the
// row with the query + match count), Backspace edits, Esc clears first.
//
// Apply shells out to the binaries directly (no wall-switcher.sh):
//   awww img <path> --transition-type <random of 5> --transition-duration 1.2 --transition-fps 60
//   matugen image <path> --prefer darkness --config ~/.config/matugen/config.toml
// matugen's config has set = false, so it only regenerates the palette — the
// bar recolors live via the colors.css FileView in shell.qml.
//
// Carousel: 11 recycled slots around a real-valued `centerPos` (animated
// toward `selected`). Slot geometry is a pure function of the signed distance
// d = wallIdx - centerPos, so positions/widths/shear morph continuously; the
// slot at the far edge teleports to the other side while its opacity is ~0.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: root

    // ---- Popups wiring (same pattern as RicePopup) ----
    property string popupName: "wall"

    // ---- picker state ----
    property var walls: []              // absolute paths, sorted
    property int selected: -1           // index into walls, -1 = unresolved
    property real centerPos: 0          // animated toward `selected`
    property bool listReady: false
    property bool queryReady: false
    property string currentPath: ""     // from `awww query`
    property bool animateNav: true      // false = next centerPos update snaps
    property bool everOpened: false     // first open snaps, later ones slide
    property real lastApply: 0          // guards double-delivered Enter events
    // type-to-search: printable keys append to `query`, Backspace pops, Esc
    // clears it first (second Esc closes). Invisible until something is typed.
    property string query: ""
    property var shown: []              // indices into `walls` matching `query`
    property int selectedPos: 0         // `selected`'s position within `shown`

    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/wallpapers/images"
    // random pick per apply. NB: 'slide' (in the old rofi script's list) is
    // NOT a valid awww transition — it fails the whole apply
    readonly property var transitions: ["fade", "wipe", "outer", "grow", "random"]

    // ---- geometry (fractions of the screen, tuned on eDP-1 1920x1080 to
    // match the skwd reference: relaxed lean, 4 strips per side, desktop
    // breathing room at the row ends) ----
    // NB: QML property names cannot start with an uppercase letter
    readonly property real scrW: screen ? screen.width : 1920
    readonly property real scrH: screen ? screen.height : 1080
    readonly property int sideSlots: 4          // strips per side of the center
    readonly property real margin: scrW * 0.05  // empty desktop at the row ends
    readonly property real slotH: Math.round(scrH * 0.45)
    // FIXED center frame — every wallpaper sits in the same box when centered
    // (non-16:9 ones center-crop, like skwd's fixed frame)
    readonly property real centerW: Math.round(slotH * 16 / 9)
    readonly property real gap: Math.round(scrH * 0.014)
    // strips sized so `sideSlots` of them fit exactly between the center and
    // the margin: pitch = (screen/2 - margin - center/2) / sideSlots
    readonly property real pitch: (scrW / 2 - margin - centerW / 2) / sideSlots
    readonly property real stripW: Math.round(pitch - gap)
    readonly property real shearK: 0.15  // |tan| of the lean (~8.5°, relaxed)
    readonly property int maxSlots: 2 * sideSlots + 1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    visible: false
    // Exclusive while mapped — the picker owns the keyboard so arrows/Enter/
    // Esc work anywhere. Unmapped windows hold no focus.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:wallswitch"

    onVisibleChanged: {
        // NB: Quickshell flips `visible` asynchronously on the actual map —
        // anything set right after Popups.active changes lands BEFORE this
        // runs, so the filter is reset on CLOSE, not on open.
        if (root.visible) {
            refresh();
            keySink.forceActiveFocus();
        } else if (query !== "") {
            query = "";             // fresh filter on every open
        }
    }

    Connections {
        target: Popups
        function onActiveChanged() {
            root.visible = (Popups.active === root.popupName);
        }
    }

    Component.onCompleted: {
        visible = (Popups.active === popupName);
        layoutSlots();
    }

    // ---- data loading (re-run on every open; both are cheap) ----
    function refresh() {
        listReady = false;
        queryReady = false;
        listProc.running = true;
        queryProc.running = true;
    }

    Process {
        id: listProc
        // argv, not string interpolation — filenames can contain anything
        command: ["sh", "-c",
            "find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) -print | sort",
            "sh", root.wallDir]
        stdout: StdioCollector {
            onStreamFinished: root.setList(text)
        }
    }

    // same parse hyprlock-auto.sh uses: `(?<=image: ).*`
    Process {
        id: queryProc
        command: ["sh", "-c", "awww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.setCurrent(text)
        }
    }

    function setList(stdoutText) {
        walls = stdoutText.split("\n").map(s => s.trim()).filter(s => s !== "");
        listReady = true;
        resolveSelection();
    }

    function setCurrent(stdoutText) {
        const p = stdoutText.trim();
        if (p) currentPath = p;
        queryReady = true;
        resolveSelection();
    }

    // Runs when either load completes; selection resolves once the list is in
    // (the query may land before or after it).
    function resolveSelection() {
        if (!listReady) return;
        everOpened = true;
        if (!walls.length) {
            selected = -1;
            rebuildShown();
            return;
        }
        let idx = currentPath ? walls.indexOf(currentPath) : -1;
        if (idx === -1) idx = (selected >= 0 && selected < walls.length) ? selected : 0;
        animateNav = false;
        selected = idx;
        animateNav = true;
        rebuildShown();
    }

    // ---- navigation ----
    onSelectedPosChanged: centerPos = selectedPos
    // THE actual filter hook — every keystroke rebuilds `shown`. (Without
    // this the query is just a string: the rebuild only ran on list-load,
    // which a seed-before-load test masks.)
    onQueryChanged: rebuildShown()

    Behavior on centerPos {
        enabled: root.animateNav && root.everOpened
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    function mod(a, n) {
        return ((a % n) + n) % n;
    }

    // indices into `walls` whose basename contains `query` (case-insensitive)
    function rebuildShown() {
        const q = query.toLowerCase();
        const list = [];
        for (let i = 0; i < walls.length; i++) {
            if (!q || basename(walls[i]).toLowerCase().includes(q)) list.push(i);
        }
        shown = list;
        // the set changed under us — snap, never fly across it
        animateNav = false;
        selectedPos = shown.indexOf(selected) !== -1 ? shown.indexOf(selected) : 0;
        centerPos = selectedPos;
        animateNav = true;
        layoutSlots();
    }

    // wallpaper path at position `pos` within `shown`
    function wallAt(pos) {
        return pos >= 0 && pos < shown.length ? walls[shown[pos]] : "";
    }

    function wallSource(pos) {
        return pos >= 0 && pos < shown.length ? "file://" + walls[shown[pos]] : "";
    }

    // shortest wrap-around distance from pos to idx (within `shown`)
    function signedDist(idx, pos) {
        const n = shown.length;
        if (!n) return 99;
        let d = (idx - pos) % n;
        if (d > n / 2) d -= n;
        if (d < -n / 2) d += n;
        return d;
    }

    function step(dir) {
        if (!shown.length) return;
        animateNav = true;
        selectedPos = mod(selectedPos + dir, shown.length);
        selected = shown[selectedPos];
    }

    // click a side strip: bring that wallpaper to the center
    function select(pos) {
        if (pos < 0 || pos >= shown.length) return;
        animateNav = true;
        selectedPos = pos;
        selected = shown[pos];
    }

    // jump without the 260ms flythrough (Home/End, big position distance)
    function jump(pos) {
        if (!shown.length) return;
        animateNav = false;
        selectedPos = mod(pos, shown.length);
        selected = shown[selectedPos];
        animateNav = true;
    }

    function basename(p) {
        return p.slice(p.lastIndexOf("/") + 1);
    }

    // ---- apply ----
    function apply() {
        if (selectedPos < 0 || selectedPos >= shown.length) return;
        // Return/Enter can be delivered to BOTH the generic and the specific
        // Keys handlers — the guard makes a double delivery a no-op
        const now = Date.now();
        if (now - lastApply < 250) return;
        lastApply = now;
        applyProc.path = walls[shown[selectedPos]];
        applyProc.trans = transitions[Math.floor(Math.random() * transitions.length)];
        applyProc.running = true;
        Popups.close();
    }

    Process {
        id: applyProc
        property string path: ""
        property string trans: "fade"
        // path/trans arrive as positional args — no quoting hazards
        command: ["sh", "-c",
            'awww img "$1" --transition-type "$2" --transition-duration 1.2 --transition-fps 60' +
            ' && matugen image "$1" --prefer darkness --config "$HOME/.config/matugen/config.toml"',
            "sh", path, trans]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) console.warn("wallswitch: apply stderr:", text.trim());
            }
        }
        onExited: (code, status) => {
            // awww failure short-circuits matugen, so the palette can never
            // desync from the wallpaper
            if (code !== 0) console.warn("wallswitch: apply failed, exit code", code);
        }
    }

    // ---- slot recycling ----
    // Each slot holds a stable position within `shown`; layoutSlots() keeps
    // the 9 indices around floor(centerPos) assigned, moving only slots whose
    // opacity is ~0.
    function layoutSlots() {
        const n = shown.length;
        if (!n) return;
        const count = Math.min(maxSlots, n);
        const half = Math.floor(maxSlots / 2);
        const need = [];
        for (let o = -half; o <= half && need.length < count; o++) {
            const idx = mod(Math.floor(centerPos) + o, n);
            if (need.indexOf(idx) === -1) need.push(idx);
        }
        for (let i = 0; i < maxSlots; i++) {
            const s = slotRepeater.itemAt(i);
            if (!s) continue;
            if (i >= count) { s.wallIdx = -1; continue; }
            if (need.indexOf(s.wallIdx) !== -1) continue;
            // this slot's index drifted out of the window — give it the
            // needed index farthest from its current position
            let farthest = -1, bestDist = -1;
            for (const idx of need) {
                if (slotAssigned(idx)) continue;
                const dist = Math.abs(signedDist(idx, centerPos) - signedDist(s.wallIdx, centerPos));
                if (dist > bestDist) {
                    bestDist = dist;
                    farthest = idx;
                }
            }
            if (farthest !== -1) s.wallIdx = farthest;
        }
    }

    function slotAssigned(idx) {
        for (let i = 0; i < maxSlots; i++) {
            const s = slotRepeater.itemAt(i);
            if (s && s.wallIdx === idx) return true;
        }
        return false;
    }

    onCenterPosChanged: layoutSlots()

    // ---- visuals ----
    // INVISIBLE full-screen shield — the carousel floats over the live
    // desktop (skwd-style, no dim). Clicking bare desktop closes it; the
    // wheel browses from anywhere.
    Item {
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Popups.lastDismiss = Date.now();
                Popups.close();
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                const delta = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x;
                if (delta !== 0) root.step(delta > 0 ? -1 : 1);
            }
        }

        // type-to-search chip — invisible until something is typed; sits
        // above the row, styled like the filename chips
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.scrH - root.slotH) / 2 - 44
            visible: root.query !== ""
            width: searchRow.implicitWidth + 24
            height: 30
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)

            Row {
                id: searchRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: root.query
                    color: Qt.rgba(1, 1, 1, 0.95)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
                // caret
                Rectangle {
                    width: 2
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                }
                Text {
                    text: root.shown.length + (root.shown.length === 1 ? " match" : " matches")
                    visible: root.query !== ""
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
            }
        }

        // no-match state (distinct from an empty wallpaper dir)
        Rectangle {
            anchors.centerIn: parent
            visible: root.query !== "" && root.listReady && !root.shown.length
            width: noMatchText.implicitWidth + 20
            height: 34
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)

            Text {
                id: noMatchText
                anchors.centerIn: parent
                text: "No matches for \"" + root.query + "\""
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: root.listReady && !root.walls.length
            width: emptyText.implicitWidth + 20
            height: 34
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)

            Text {
                id: emptyText
                anchors.centerIn: parent
                text: "No wallpapers in " + root.wallDir
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
        }
    }

    Repeater {
        id: slotRepeater
        model: root.maxSlots

        delegate: Item {
            id: slot

            property int wallIdx: -1
            readonly property real d: root.signedDist(wallIdx, root.centerPos)
            readonly property real ad: Math.abs(d)
            readonly property real t: Math.min(ad, 1)          // 0 = center, 1 = full strip
            readonly property bool isCenter: ad < 0.5
            readonly property bool hovered: stripArea.containsMouse
            // uniform shear across ALL slots — the center leans exactly like
            // the strips (skwd's whole plane shares one angle)
            readonly property real shearAmt: root.shearK

            visible: wallIdx >= 0 && ad < 4.6
            // the row ends at |d| = 4; the 5th slot is never shown — it only
            // exists as an invisible teleport target for recycling
            opacity: ad <= 4 ? 1 : Math.max(0, 1 - (ad - 4) * 2)
            z: Math.round(100 - ad * 10)

            width: root.centerW + (root.stripW - root.centerW) * t
            height: root.slotH
            x: root.scrW / 2 + (d > 0.001 ? 1 : d < -0.001 ? -1 : 0) * slotOffset(ad) - width / 2
            y: (root.scrH - height) / 2

            // center-to-strip distance for a slot at |d| = tt; the first
            // strip hugs the center image's edge, later ones step by one
            // pitch (pitch/stripW are derived so sideSlots fit the margin)
            function slotOffset(tt) {
                const full = root.centerW / 2 + root.gap + root.stripW / 2;
                if (tt <= 1) return tt * full;
                return full + (tt - 1) * root.pitch;
            }

            // center-vs-strip morph target; the center frame is FIXED 16:9
            // (centerW), so no aspect feedback loop is needed

            // sheared window: the clip rect lives INSIDE the transform, so the
            // strip is a clean parallelogram slice (clipping a sheared image
            // directly would spill unsheared content over the neighbors)
            Item {
                id: shearWrap
                anchors.fill: parent
                transform: Matrix4x4 {
                    // x' = x - k*y + k*H/2 (shear about the vertical middle);
                    // m12 = -k puts the TOP edge to the right = right-leaning.
                    // Applied to the center slot too — one uniform angle.
                    matrix: Qt.matrix4x4(
                        1, -slot.shearAmt, 0, slot.shearAmt * slot.height / 2,
                        0, 1, 0, 0,
                        0, 0, 1, 0,
                        0, 0, 0, 1)
                }

                Item {
                    id: window
                    anchors.fill: parent
                    clip: true

                    Image {
                        id: img
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        source: root.wallSource(slot.wallIdx)
                        // decode cap: quantized so the continuous width morph
                        // doesn't re-decode every frame
                        sourceSize.width: Math.max(64, Math.ceil(width / 128) * 128)
                        sourceSize.height: 0
                    }

                    // dim overlay (center is undimmed); hover brightens
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: slot.hovered ? 0.5 * slot.t * 0.3 : 0.5 * slot.t
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }

                    // accent border, solid only at the center slot (like the
                    // reference's highlighted selection)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        opacity: 1 - slot.t
                        visible: opacity > 0.02
                    }
                }
            }

            // filename chip, bottom-left of every slot (the reference's "PIC")
            Rectangle {
                id: chip
                x: 6
                y: parent.height - 27
                width: Math.min(chipText.implicitWidth + 14, parent.width - 12)
                height: 21
                radius: 3
                color: Qt.rgba(0, 0, 0, 0.55)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
                // filename chip only on the focused wallpaper (pure visibility
                // toggle — no image reloads involved)
                visible: slot.wallIdx === root.selectedPos

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, chip.width - 10)
                    elide: Text.ElideRight
                    text: slot.wallIdx >= 0 ? root.basename(root.wallAt(slot.wallIdx)) : ""
                    color: Qt.rgba(1, 1, 1, 0.92)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
            }

            MouseArea {
                id: stripArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: slot.isCenter ? root.apply() : root.select(slot.wallIdx)
            }
        }
    }

    // keyboard focus sink while the picker is open
    Item {
        id: keySink
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) {
                // first Esc clears an active search, second closes
                if (root.query !== "") root.query = "";
                else Popups.close();
                event.accepted = true;
            } else if (k === Qt.Key_Backspace) {
                if (root.query !== "") root.query = root.query.slice(0, -1);
                event.accepted = true;
            } else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) {
                root.step(-1);
                event.accepted = true;
            } else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) {
                root.step(1);
                event.accepted = true;
            } else if (k === Qt.Key_Home) {
                root.jump(0);
                event.accepted = true;
            } else if (k === Qt.Key_End) {
                root.jump(root.shown.length - 1);
                event.accepted = true;
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space
                    || event.text === "\r" || event.text === "\n") {
                root.apply();
                event.accepted = true;
            } else if (event.text.length === 1 && event.text >= "!"
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                // printable character — type to search (Space still applies)
                root.query += event.text;
                event.accepted = true;
            } else if (k >= 0x01000000) {
                // unrecognized extended key — surface it (console.log is lost,
                // warn reaches the qs log). Letters/punctuation stay silent.
                console.warn("wallswitch: unhandled key", k, JSON.stringify(event.text));
            }
        }
        // belt and braces: some stacks hand Return/Enter to the specific
        // handlers instead of onPressed — lastApply guards double-fires
        Keys.onReturnPressed: root.apply()
        Keys.onEnterPressed: root.apply()
    }
}
