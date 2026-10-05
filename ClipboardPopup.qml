import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

// Clipboard history panel — cliphist backend, rofi-picker replacement.
// Data: one `cliphist list` per open (tab-separated `id\tpreview`, multi-line
// continuations ignored), classified text/link/image in JS; every keystroke
// filters that in-memory list. `cliphist decode` runs strictly on demand:
// restore, delete, expand-text, or an image preview's first render
// (cached under ~/.cache/quickshell_rice/, so later opens are free).
RicePopup {
    id: root

    popupName: "clip"
    keyNavEnabled: true
    centerOnAnchor: true

    // ---- tweak me ----
    property int panelW: 640      // -> panelWidth
    property int panelH: 660      // -> panelHeight (clamped to the screen)
    // (the position knob is the anchorX line on the instance in Bar.qml)
    panelWidth: panelW
    panelHeight: panelH

    // ---- state ----
    property var entries: []            // {id, raw, preview, cat, ext?, w?, h?}
    property var pins: []               // pinned cliphist ids (numbers)
    // search text lives IN the field (single source of truth) — the filter
    // binding reads it, so typing filters with zero glue code
    property alias searchText: searchField.text
    property string activeCat: "all"    // all | text | image | link
    property int selIndex: 0            // position within `shown` (keyboard nav)
    property var expandedText: ({})     // id -> decoded full text
    property var bigImages: []          // ids currently expanded
    property var thumbs: []             // ids with a cached thumbnail on disk
    property var thumbQueue: []         // pending thumbnail decodes

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell_rice"

    function isPinned(id) {
        return pins.indexOf(id) !== -1;
    }

    // pinned cards first (stable sort keeps cliphist recency inside groups)
    readonly property var ordered:
        entries.slice().sort((a, b) => (isPinned(b.id) ? 1 : 0) - (isPinned(a.id) ? 1 : 0))

    readonly property var counts: {
        let t = 0, i = 0, l = 0;
        for (let k = 0; k < entries.length; k++) {
            if (entries[k].cat === "text") t++;
            else if (entries[k].cat === "image") i++;
            else l++;
        }
        return { all: entries.length, text: t, image: i, link: l };
    }

    // category + case-insensitive preview substring; images only match an
    // empty query (their preview is just the binary header — nothing to
    // search, and full-content search would decode everything per keystroke)
    readonly property var shown: {
        const q = searchText.toLowerCase();
        return ordered.filter(e => {
            if (activeCat !== "all" && e.cat !== activeCat) return false;
            return q === "" || (e.cat !== "image" && e.preview.toLowerCase().includes(q));
        });
    }

    function entryAt(pos) {
        return pos >= 0 && pos < shown.length ? shown[pos] : null;
    }

    // links in accent only when the accent is actually readable on the panel
    // (light palettes often ship a near-white accent), else body color
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    readonly property color linkColor:
        Math.abs(lum(Theme.accent) - lum(Theme.popupBg)) > 0.35 ? Theme.accent : Theme.fg

    // live refresh while open: new copies appear within ~2s. cliphist list
    // is ~30KB and parsing is ~1ms — nothing.
    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: listProc.running = true
    }

    function thumbPath(e) {
        return cacheDir + "/clipboard-" + e.id + "." + (e.ext || "png");
    }

    // NB: Connections, not an onVisibleChanged override — a subclass handler
    // would shadow RicePopup's own visible-changed bookkeeping
    Connections {
        target: root
        function onVisibleChanged() {
            if (!root.visible) return;
            searchField.clear();
            activeCat = "all";
            selIndex = 0;
            listProc.running = true;
            pinsReader.running = true;
            searchField.forceActiveFocus();
        }
    }

    // ---- data loading ----
    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseList(text)
        }
    }

    function parseList(stdoutText) {
        const row = /^(\d+)\t(.*)$/;
        const img = /^\[\[ binary data .*? (\w+) (\d+)x(\d+) \]\]/;
        const out = [];
        for (const line of stdoutText.split("\n")) {
            const m = line.match(row);
            if (!m) continue;                       // multi-line continuation
            const preview = m[2];
            if (preview.startsWith("<meta http-equiv=")) continue;
            const im = preview.match(img);
            if (im) {
                out.push({ id: +m[1], raw: line, preview, cat: "image",
                           ext: im[1], w: +im[2], h: +im[3] });
            } else if (/^https?:\/\//.test(preview)) {
                out.push({ id: +m[1], raw: line, preview, cat: "link" });
            } else {
                out.push({ id: +m[1], raw: line, preview, cat: "text" });
            }
        }
        entries = out;
        // NB: no selIndex reset here — the 2s live poll reparses and must not
        // yank the selection back to the top (open resets it instead)
    }

    // ---- pins (sidecar file: one id per line; stale ids are pruned silently) ----
    // read via a Process, not FileView — a missing file is the normal
    // first-run state and FileView's failed-load callback timing is exactly
    // the kind of ambiguity that once reverted a pin race-style
    Process {
        id: pinsReader
        command: ["sh", "-c",
            'mkdir -p "$(dirname "$1")"; [ -f "$1" ] && cat "$1" || true',
            "sh", cacheDir + "/clipboard-pins"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePins(text)
        }
    }

    function parsePins(fileText) {
        pins = fileText.split("\n").map(s => s.trim()).filter(s => s !== "").map(Number);
    }

    function togglePin(id) {
        pins = isPinned(id) ? pins.filter(x => x !== id) : pins.concat([id]);
        persistPins();
    }

    Process {
        id: pinsWriter
        command: []
    }

    function persistPins() {
        pinsProcPayload = pins.length ? pins.join("\n") + "\n" : "";
        pinsWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"',
            "sh", pinsProcPayload, cacheDir + "/clipboard-pins"];
        pinsWriter.running = true;
    }
    property string pinsProcPayload: ""

    // ---- image thumbnails (decode once per id, cached on disk) ----
    Process {
        id: thumbProc
        property int outId: -1
        command: []
        onExited: (code, status) => {
            if (code === 0) thumbs = thumbs.concat([outId]);
            thumbQueue = thumbQueue.slice(1);
            pumpThumbs();
        }
    }

    function requestThumb(e) {
        if (thumbs.indexOf(e.id) !== -1) return;
        for (let i = 0; i < thumbQueue.length; i++)
            if (thumbQueue[i].id === e.id) return;
        thumbQueue = thumbQueue.concat([e]);
        pumpThumbs();
    }

    function pumpThumbs() {
        if (thumbProc.running || !thumbQueue.length) return;
        const e = thumbQueue[0];
        thumbProc.outId = e.id;
        thumbProc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && cliphist decode "$1" > "$2"',
            "sh", e.raw, thumbPath(e)];
        thumbProc.running = true;
    }

    // ---- expand (text decodes on demand; images are pure UI) ----
    Process {
        id: expandProc
        property int outId: -1
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.expandedText =
                Object.assign({}, root.expandedText, { [expandProc.outId]: text })
        }
    }

    function toggleExpand(e) {
        if (e.cat === "image") {
            bigImages = bigImages.indexOf(e.id) === -1
                ? bigImages.concat([e.id]) : bigImages.filter(x => x !== e.id);
            return;
        }
        if (expandedText[e.id] !== undefined) {
            const copy = Object.assign({}, expandedText);
            delete copy[e.id];
            expandedText = copy;
            return;
        }
        if (expandProc.running) return;
        expandProc.outId = e.id;
        expandProc.command = ["sh", "-c",
            'printf "%s\\n" "$1" | cliphist decode | head -c 65536', "sh", e.raw];
        expandProc.running = true;
    }

    // ---- actions ----
    Process {
        id: restoreProc
        command: []
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("clip: restore stderr:", text.trim())
        }
    }

    function restore(e) {
        restoreProc.command = ["sh", "-c",
            'printf "%s\\n" "$1" | cliphist decode | wl-copy', "sh", e.raw];
        restoreProc.running = true;
        Popups.close();
    }

    Process {
        id: deleteProc
        command: []
    }

    function remove(e) {
        deleteProc.command = ["sh", "-c",
            'printf "%s\\n" "$1" | cliphist delete', "sh", e.raw];
        deleteProc.running = true;
        entries = entries.filter(x => x.id !== e.id);
    }

    // ---- keyboard nav (cards only; the buttons are mouse-only) ----
    function move(dir) {
        if (!shown.length) return;
        selIndex = (selIndex + dir + shown.length) % shown.length;
    }

    onSelIndexChanged: {
        if (cardList.count > 0)
            cardList.positionViewAtIndex(selIndex, ListView.Contain);
    }
    onShownChanged: if (selIndex >= shown.length) selIndex = Math.max(0, shown.length - 1)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── search row ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 12
            color: Theme.inputBg

            NIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                iconSize: 14
                iconColor: Theme.fgMuted
            }

            TextField {
                id: searchField
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                background: Item {}
                placeholderText: "Search clipboard history"
                placeholderTextColor: Theme.fgMuted
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
                verticalAlignment: TextInput.AlignVCenter
                focus: root.visible

                // arrows/Tab iterate the cards; typing (and Left/Right/Home/
                // End cursor keys) stay in the field. NB: Tab has no dedicated
                // Keys.* shortcut handler — it must route through onPressed.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        root.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.move(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        root.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backtab) {
                        root.move(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        const e = root.entryAt(root.selIndex);
                        if (e) root.restore(e);
                        event.accepted = true;
                    }
                }
                Keys.onEscapePressed: event => {
                    // first Esc clears the search, second closes — the field
                    // closes explicitly: relying on the event bubbling to the
                    // body's handler proved unreliable in practice
                    if (text !== "") clear();
                    else Popups.close();
                    event.accepted = true;
                }
            }

            //not needed
            // Text {
            //     id: keyHint
            //     anchors.right: parent.right
            //     anchors.rightMargin: 10
            //     anchors.verticalCenter: parent.verticalCenter
            //     text: "Super V"
            //     color: Theme.fgMuted
            //     font.family: Theme.fontFamily
            //     font.pixelSize: Theme.textSize - 2
            // }
        }

        // ── filter chips ──
        Row {
            spacing: 6

            Repeater {
                model: [
                    { key: "all", label: "All" },
                    { key: "text", label: "Text" },
                    { key: "image", label: "Image" },
                    { key: "link", label: "Link" }
                ]

                delegate: Rectangle {
                    id: chip
                    required property var modelData

                    width: chipRow.implicitWidth + 16
                    height: 26
                    radius: 9
                    color: root.activeCat === chip.modelData.key ? Theme.accentSoft : "transparent"
                    border.width: root.activeCat === chip.modelData.key ? 1 : 0
                    border.color: Theme.accent

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: chip.modelData.label
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSize
                        }
                        Text {
                            text: root.counts[chip.modelData.key]
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSize
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeCat = chip.modelData.key
                    }
                }
            }
        }

        // ── cards ──
        ListView {
            id: cardList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: Theme.fg
                    opacity: 0.3
                }
                background: Item {}
            }

            model: ScriptModel { values: root.shown }

            delegate: Item {
                id: card
                required property var modelData
                required property int index

                readonly property var e: modelData
                // NB: HoverHandler, not rowMa.containsMouse — rowMa sits
                // UNDER the buttons now, and a MouseArea loses hover to
                // whatever is on top (the ✕ would vanish when the mouse
                // reached it). HoverHandler is passive and sees everything.
                readonly property bool hovered: cardHover.hovered
                readonly property bool selected: index === root.selIndex
                readonly property bool pinned: root.isPinned(e.id)
                readonly property bool expanded: e.cat === "image"
                    ? root.bigImages.indexOf(e.id) !== -1
                    : root.expandedText[e.id] !== undefined

                // 14px narrower than the list: keeps the button column clear
                // of the vertical scrollbar (Flickable has no padding)
                width: cardList.width - 14
                height: cardCol.implicitHeight

                // NB: delegate recycles — request the thumbnail whenever the
                // entry changes, not just on creation (Component.onCompleted
                // never re-fires for a reused delegate)
                onEChanged: if (e.cat === "image") root.requestThumb(e)

                // click-to-restore surface. Declared FIRST = lowest z, so the
                // button column above receives its own clicks; plain Rectangles
                // pass clicks through to here.
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restore(card.e)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: card.hovered || card.selected ? Theme.rowHover : "transparent"
                    border.width: card.selected ? 1 : 0
                    border.color: Theme.accent
                }

                Row {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: 6

                    // ── inset content box ──
                    Rectangle {
                        width: parent.width - buttons.width - parent.spacing
                        height: contentBox.implicitHeight + 16
                        radius: 10
                        // fg-derived tone: stays visible on light AND dark
                        // palettes (inputBg washed out to near-white here)
                        color: Theme.track
                        clip: true

                        Column {
                            id: contentBox
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 8
                            anchors.verticalCenter: parent.verticalCenter

                            // text: preview collapsed (3 lines), decoded content expanded
                            Text {
                                visible: card.e.cat !== "image"
                                width: parent.width
                                text: card.e.cat === "text"
                                    ? (root.expandedText[card.e.id] !== undefined
                                        ? root.expandedText[card.e.id] : card.e.preview)
                                    : card.e.preview
                                wrapMode: Text.Wrap
                                maximumLineCount: card.expanded && card.e.cat === "text" ? 9999 : 3
                                elide: Text.ElideRight
                                color: card.e.cat === "link" ? root.linkColor : Theme.fg
                                font.underline: card.e.cat === "link"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSize
                            }

                            // image: cached thumbnail; 110px collapsed, true aspect expanded
                            Item {
                                visible: card.e.cat === "image"
                                width: parent.width
                                height: card.expanded
                                    ? Math.min(420, width * card.e.h / Math.max(1, card.e.w))
                                    : 110

                                Image {
                                    anchors.fill: parent
                                    visible: root.thumbs.indexOf(card.e.id) !== -1
                                    source: visible ? "file://" + root.thumbPath(card.e) : ""
                                    fillMode: card.expanded ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: card.expanded ? 1024 : 220
                                    sourceSize.height: 0
                                }
                                NIcon {
                                    anchors.centerIn: parent
                                    visible: root.thumbs.indexOf(card.e.id) === -1
                                    name: "clipboard"
                                    iconSize: 22
                                    iconColor: Theme.fgMuted
                                }
                            }
                        }
                    }

                    // ── right button column (mouse-only by design: never
                    // focused, not in the tab order, no keybinds) ──
                    Column {
                        id: buttons
                        width: 24
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Component.onCompleted: if (card.e.cat === "image") root.requestThumb(card.e)

                        Repeater {
                            // NB: hover must NOT live in this model (it would
                            // rebuild all buttons every time the mouse crosses
                            // a row) — the delete button reads hovered itself.
                            // Expand shows only when there is something beyond
                            // the preview: images always, text when cliphist
                            // truncated it (its marker is a trailing "…") or
                            // when already expanded (= shrink).
                            model: [
                                { icon: card.expanded ? "shrink" : "expand",
                                  show: card.e.cat === "image"
                                      || (card.e.cat === "text"
                                          && (card.expanded || /\u2026$|\.\.\.$/.test(card.e.preview))),
                                  act: () => root.toggleExpand(card.e) },
                                { icon: card.pinned ? "starFill" : "star", show: true, act: () => root.togglePin(card.e.id) },
                                { icon: "xmark", show: true, act: () => root.remove(card.e) }
                            ]

                            delegate: Rectangle {
                                id: btn
                                required property var modelData
                                required property int index
                                readonly property bool show: modelData.show
                                // delete is hover-only, but it must RESERVE its
                                // slot — visible:false would shrink the column
                                // (Column layout skips invisible children) and
                                // resize the card on every hover
                                readonly property bool deleteSlot: index === 2

                                width: 24
                                height: 22
                                radius: 8
                                visible: show
                                opacity: !deleteSlot || card.hovered ? 1 : 0
                                enabled: !deleteSlot || card.hovered
                                color: btnMa.containsMouse ? Theme.accent : "transparent"

                                NIcon {
                                    anchors.centerIn: parent
                                    name: btn.modelData.icon
                                    iconSize: 13
                                    iconColor: Theme.fgMuted
                                }
                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: btn.modelData.act()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── empty state ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: cardList.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 12

                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "clipboard"
                    iconSize: 42
                    iconColor: Theme.fgMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.entries.length === 0 ? "Clipboard is empty" : "No matches"
                    color: Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
            }
        }
    }
}
