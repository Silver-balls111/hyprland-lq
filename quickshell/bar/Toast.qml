import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Toast stack — every notification shows its own banner at the top-right
// (newest on top, older ones pushed down), each retiring when its own
// deadline passes. Small mapped-only window (TooltipWindow pattern: no input
// masks on 0.3.1). Click a banner to expand/collapse the full body (its
// deadline freezes while expanded); the corner ✕ dismisses it.
//
// The stack is mirrored into a ListModel (same pattern as NotifsPanel):
// Notifs.activeToasts is a plain array reassigned on EVERY push/dismiss, and
// a Repeater over it destroys and recreates ALL cards each time — a ✕ click
// landing during a rebuild hit a destroyed delegate and was silently lost.
// With the ListModel, cards are inserted/removed incrementally; a delegate
// only dies when ITS toast leaves. Card → entry back-references are resolved
// by the entry's stable `id` (entry objects survive the array reassignments).
PanelWindow {
    id: root

    readonly property bool showing: Notifs.activeToasts.length > 0 && Popups.active !== "clock"
    visible: showing

    anchors {
        top: true
        right: true
    }
    // must ignore exclusive zones — otherwise Hyprland pushes the toast below
    // the bar's 46px zone (same gotcha as TooltipWindow)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: -1
    implicitWidth: 400
    implicitHeight: stackCol.implicitHeight
    margins.right: 10
    // shift down below the OSD while one is showing (same corner)
    margins.top: Theme.barHeight + 8 + (Notifs.osdShowing ? Theme.osdHeight + 8 : 0)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:toast"

    // expiry ticker (Notifs is a QtObject singleton and cannot host children)
    Timer {
        interval: 250
        running: Notifs.activeToasts.length > 0
        repeat: true
        onTriggered: Notifs.expireTick()
    }

    ListModel {
        id: toastModel
    }
    function findRow(id) {
        for (let r = 0; r < toastModel.count; r++)
            if (toastModel.get(r).entryId === id) return r;
        return -1;
    }
    function syncToasts() {
        const want = Notifs.activeToasts;
        for (let r = toastModel.count - 1; r >= 0; r--)
            if (want.findIndex(e => e.id === toastModel.get(r).entryId) === -1)
                toastModel.remove(r);
        // ascending: want[0..i-1] are all present by the time row i inserts,
        // so index i is always ≤ count (a descending loop would reject)
        for (let i = 0; i < want.length; i++) {
            if (findRow(want[i].id) === -1)
                toastModel.insert(i, {
                    entryId: want[i].id,
                    appName: want[i].appName,
                    summary: want[i].summary,
                    body: want[i].body,
                    urgency: want[i].urgency,
                    expanded: false
                });
        }
    }
    Connections {
        target: Notifs
        function onActiveToastsChanged() {
            syncToasts();
        }
    }
    Component.onCompleted: syncToasts()

    Column {
        id: stackCol
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.left: parent.left
        spacing: 8

        Repeater {
            model: toastModel

            delegate: Rectangle {
                id: toastCard
                required property int index
                required property int entryId
                required property string appName
                required property string summary
                required property string body
                required property int urgency
                required property bool expanded

                readonly property bool urgent: urgency === 2

                width: stackCol.width
                height: cardCol.implicitHeight + 20
                radius: 12
                color: Theme.popupBg
                border.width: 1
                border.color: urgent ? Theme.danger : Theme.border

                Rectangle {
                    id: iconChip
                    width: 36
                    height: 36
                    radius: 8
                    color: Theme.inputBg
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    NIcon {
                        anchors.centerIn: parent
                        name: "bell"
                        iconSize: 17
                        iconColor: Theme.fgMuted
                    }
                }

                Column {
                    id: cardCol
                    anchors.left: iconChip.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: toastCard.expanded ? 22 : 10
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 2

                    Text {
                        width: parent.width
                        text: toastCard.appName
                        elide: Text.ElideRight
                        visible: text !== ""
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: toastCard.summary !== "" ? toastCard.summary : toastCard.appName
                        // match NotifsPanel: summary un-truncates when the
                        // card is expanded — no "…" on the title line either
                        wrapMode: Text.Wrap
                        elide: toastCard.expanded ? Text.ElideNone : Text.ElideRight
                        maximumLineCount: toastCard.expanded ? 1000 : 1
                        color: toastCard.urgent ? Theme.danger : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: toastCard.body
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        elide: toastCard.expanded ? Text.ElideNone : Text.ElideRight
                        maximumLineCount: toastCard.expanded ? 1000 : 1
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const nv = !toastCard.expanded;
                        toastModel.setProperty(toastCard.index, "expanded", nv);
                        // mirror into the entry: Notifs.expireTick reads
                        // entry.expanded, and collapsing re-arms its deadline
                        const e = Notifs.activeToasts.find(t => t.id === toastCard.entryId);
                        if (e) {
                            e.expanded = nv;
                            if (!nv)
                                e.expiresAt = Math.max(e.expiresAt, Date.now() + 2000);
                        }
                    }
                }

                // dismiss ✕ — declared AFTER the fullscreen MouseArea so it
                // sits on top (a covered MouseArea never sees the click)
                NIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    name: "xmark"
                    iconSize: 12
                    iconColor: Theme.fgMuted

                    MouseArea {
                        anchors.fill: parent
                        // generous hit target around the 12px glyph
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const e = Notifs.activeToasts.find(t => t.id === toastCard.entryId);
                            if (e) Notifs.dismissToast(e, true);
                        }
                    }
                }
            }
        }
    }
}
