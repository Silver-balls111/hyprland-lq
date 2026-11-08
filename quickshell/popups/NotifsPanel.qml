import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// Notifications column of the dashboard: MPRIS player card(s) docked on top,
// notification history below (scrolls), DND + Clear footer. The media card only
// takes space from the list — the panel height is fixed by DashPopup.
Item {
    id: root

    // any player that isn't fully stopped (paused players stay visible)
    readonly property var activePlayers:
        Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)

    // ── notification history (scrolls) ──
    // The panel mirrors Notifs.history into a ListModel so mutations are
    // INCREMENTAL: a plain-array model resets the ListView on every change,
    // which rebuilt all delegates — wiping per-row expanded state whenever
    // any other row was removed — and made per-item animations impossible.
    // Rows are keyed by the entry's stable `id`; expansion lives as a role.
    ListModel {
        id: historyModel
    }
    function findRow(id) {
        for (let r = 0; r < historyModel.count; r++)
            if (historyModel.get(r).entryId === id) return r;
        return -1;
    }
    // ── Clear-all: staggered in-place swipe-out ──
    // Clear NEVER removes a visible row: removing them one by one reflows the
    // rows below, which hopped up a slot ("staggered") while the row above was
    // still swiping right. Instead every row swipes out IN PLACE — staggered
    // top-down from the delegate via its `leaving` role — and the model is
    // dropped in ONE pass after the last swipe finished, so nothing ever
    // reflows while anything is visible. (A normal ✕ keeps hop-up: its
    // survivors SHOULD move up.)
    property bool clearing: false
    readonly property int staggerMs: 150
    function beginClear() {
        clearing = true;
        // one swipe = 240ms slide + 180ms fade; the last row's pause is
        // stagger * (count - 1) — finish just after it, with slack
        clearFinish.interval = staggerMs * Math.max(0, historyModel.count - 1) + 450;
        clearFinish.restart();
        for (let i = 0; i < historyModel.count; i++)
            historyModel.setProperty(i, "leaving", true);
    }

    function syncHistory() {
        const want = Notifs.history;
        // empty history = Clear, or a ✕ on the only row: every current row
        // gets its own in-place swipe instead of a bare model reset that
        // would skip the animations
        if (want.length === 0) {
            if (historyModel.count > 0) beginClear();
            return;
        }
        // a non-empty sync while the swipe-out is running (a toast arrived
        // mid-clear) aborts it: restore the rows, finisher becomes a no-op
        if (clearing) {
            clearing = false;
            clearFinish.stop();
            for (let r = 0; r < historyModel.count; r++)
                historyModel.setProperty(r, "leaving", false);
        }
        for (let r = historyModel.count - 1; r >= 0; r--) {
            const rid = historyModel.get(r).entryId;
            if (want.findIndex(e => e.id === rid) === -1)
                historyModel.remove(r);
        }
        // fresh model (popup is lazy — this runs on every open with the full
        // history already in `want`): append newest-first in one pass. The
        // descending insert(i) loop below REJECTS index > count ("insert:
        // index N out of range") and used to leave only the newest row.
        if (historyModel.count === 0) {
            for (let j = 0; j < want.length; j++)
                historyModel.append({
                    entryId: want[j].id,
                    appName: want[j].appName,
                    summary: want[j].summary,
                    body: want[j].body,
                    urgency: want[j].urgency,
                    expanded: false,
                    leaving: false
                });
            return;
        }
        for (let i = want.length - 1; i >= 0; i--) {
            if (findRow(want[i].id) === -1)
                historyModel.insert(i, {
                    entryId: want[i].id,
                    appName: want[i].appName,
                    summary: want[i].summary,
                    body: want[i].body,
                    urgency: want[i].urgency,
                    expanded: false,
                    leaving: false
                });
        }
    }
    // once the last swipe-out has finished, drop the whole model in one pass —
    // every row is already at opacity 0, so this triggers no visible animations
    Timer {
        id: clearFinish
        onTriggered: {
            if (!root.clearing) return;
            root.clearing = false;
            historyModel.clear();
        }
    }
    Connections {
        target: Notifs
        function onHistoryChanged() {
            syncHistory();
        }
    }
    Component.onCompleted: syncHistory()

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── media cards ──
        Repeater {
            model: ScriptModel {
                values: root.activePlayers
            }

            delegate: Rectangle {
                id: playerCard
                required property var modelData
                readonly property var player: modelData

                Layout.fillWidth: true
                height: 76
                radius: 12
                color: Theme.rowHover

                Rectangle {
                    id: art
                    width: 48
                    height: 48
                    radius: 8
                    clip: true
                    color: Theme.inputBg
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        visible: playerCard.player.trackArtUrl !== ""
                        source: playerCard.player.trackArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    NIcon {
                        anchors.centerIn: parent
                        visible: playerCard.player.trackArtUrl === ""
                        name: "music"
                        iconSize: 22
                        iconColor: Theme.fgMuted
                    }
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 10
                    anchors.right: controls.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: playerCard.player.identity
                        elide: Text.ElideRight
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: playerCard.player.trackTitle !== "" ? playerCard.player.trackTitle : playerCard.player.identity
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        visible: playerCard.player.trackArtists !== ""
                        text: playerCard.player.trackArtists
                        elide: Text.ElideRight
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }

                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "prev", enabled: playerCard.player.canGoPrevious, action: () => playerCard.player.previous() },
                            { icon: playerCard.player.isPlaying ? "pause" : "play", enabled: playerCard.player.canTogglePlaying, action: () => playerCard.player.togglePlaying() },
                            { icon: "next", enabled: playerCard.player.canGoNext, action: () => playerCard.player.next() }
                        ]

                        delegate: Rectangle {
                            id: ctrlBtn
                            required property var modelData
                            readonly property bool usable: modelData.enabled

                            width: 26
                            height: 26
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: ctrlMa.containsMouse && usable ? Theme.accent : "transparent"
                            opacity: usable ? 1 : 0.35

                            NIcon {
                                anchors.centerIn: parent
                                name: ctrlBtn.modelData.icon
                                iconSize: 14
                            }
                            MouseArea {
                                id: ctrlMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: ctrlBtn.usable
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrlBtn.modelData.action()
                            }
                        }
                    }
                }
            }
        }


        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0 || root.clearing
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            // new notifications fade in IN PLACE (no slide); survivors shift smoothly
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
            }
            // 180ms OutCubic — must match the row height Behavior exactly,
            // otherwise the displaced row outruns/lags the growing/shrinking
            // row above and a background-colored gap flashes between them
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
            }
            removeDisplaced: Transition {
                NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
            }

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

            model: historyModel

            delegate: Rectangle {
                id: notifRow
                required property int index
                required property int entryId
                required property string appName
                required property string summary
                required property string body
                required property int urgency
                required property bool expanded
                required property bool leaving

                width: notifList.width - 14
                // expansion grows DOWNWARD only: content is top-anchored, so
                // the top edge stays put and rows below get pushed down
                // (center-anchored content made the row grow both ways — the
                // "bouncy" effect)
                height: expanded ? contentCol.implicitHeight + 14 : 48
                radius: 12
                color: rowMa.containsMouse ? Theme.rowHover : "transparent"

                Behavior on height {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // swipe-out on ✕ removal (Clear instead runs the in-place
                // `leaveAnim` via the `leaving` role)
                // NB: the animation is a declared object driven from the signal
                // handler — assigning the object DIRECTLY to onRemove is the
                // deprecated "object to signal handler" pattern Qt warns about
                SequentialAnimation {
                    id: removeAnim
                    PropertyAction { target: notifRow; property: "ListView.delayRemove"; value: true }
                    NumberAnimation { target: notifRow; property: "x"; to: notifRow.width + 40; duration: 240; easing.type: Easing.InQuad }
                    NumberAnimation { target: notifRow; property: "opacity"; to: 0; duration: 180 }
                    PropertyAction { target: notifRow; property: "ListView.delayRemove"; value: false }
                }
                ListView.onRemove: {
                    // the in-place `leaveAnim` owns the row during Clear; only
                    // a model removal NOT driven by Clear (the ✕) animates here
                    if (!notifRow.leaving) removeAnim.start()
                }

                // Clear's in-place swipe-out: the row stays in the model the
                // whole time, so nothing below it is ever displaced (see the
                // `clearing` notes). The pause is per-index, so the newest row
                // (top) leaves first and the sweep rolls down the list.
                SequentialAnimation {
                    id: leaveAnim
                    PauseAnimation { duration: notifRow.index * root.staggerMs }
                    NumberAnimation { target: notifRow; property: "x"; to: notifRow.width + 40; duration: 240; easing.type: Easing.InQuad }
                    NumberAnimation { target: notifRow; property: "opacity"; to: 0; duration: 180 }
                }
                onLeavingChanged: {
                    if (leaving) {
                        leaveAnim.start();
                    } else {
                        // mid-clear abort (a new toast arrived): restore the row
                        leaveAnim.stop();
                        notifRow.x = 0;
                        notifRow.opacity = 1;
                    }
                }

                Rectangle {
                    id: iconChip
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.inputBg
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.top: parent.top
                    anchors.topMargin: 8

                    NIcon {
                        anchors.centerIn: parent
                        name: "bell"
                        iconSize: 15
                        iconColor: Theme.fgMuted
                    }
                }

                Column {
                    id: contentCol
                    anchors.left: iconChip.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    spacing: 2

                    Text {
                        width: parent.width
                        text: notifRow.summary !== "" ? notifRow.summary : notifRow.appName
                        elide: Text.ElideRight
                        color: notifRow.urgency === 2 ? Theme.danger : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        visible: notifRow.body !== ""
                        text: notifRow.body
                        wrapMode: Text.Wrap
                        elide: notifRow.expanded ? Text.ElideNone : Text.ElideRight
                        maximumLineCount: notifRow.expanded ? 1000 : 1
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }

                // dismiss affordance — hover-revealed; its own MouseArea sits
                // ABOVE rowMa but with hoverEnabled: false, so it takes the
                // click while rowMa keeps the hover (the ✕ never flickers
                // away under the cursor)
                NIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "xmark"
                    iconSize: 12
                    iconColor: Theme.fgMuted
                    opacity: rowMa.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: historyModel.setProperty(notifRow.index, "expanded", !notifRow.expanded)
                }

                MouseArea {
                    id: xMa
                    width: 26
                    height: parent.height
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    hoverEnabled: false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.remove(notifRow.index)
                }
            }
        }

        // ── empty state ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: notifList.count === 0 && !root.clearing

            Column {
                anchors.centerIn: parent
                spacing: 12

                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "bell"
                    iconSize: 42
                    iconColor: Theme.fgMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No Notifications"
                    color: Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
            }
        }

        // ── footer: DND + Clear ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Do Not Disturb"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
            Toggle {
                Layout.alignment: Qt.AlignVCenter
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }
            Rectangle {
                id: clearBtn
                width: 56
                height: 26
                radius: 9
                color: clearMa.containsMouse ? Theme.accent : Theme.rowHover

                Text {
                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }
        }
    }
}
