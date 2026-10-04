import QtQuick
import Quickshell
import Quickshell.Wayland

// Transient toast banner for the newest notification — the swaync replacement.
// Small mapped-only window (TooltipWindow pattern: no input masks on 0.3.1).
// Timings mirror the user's old swaync config: 2s low / 4s normal / 6s critical;
// an app-supplied expireTimeout wins when present (clamped 2-15s).
PanelWindow {
    id: root

    readonly property var entry: Notifs.toast
    readonly property bool showing: entry !== null && Popups.active !== "clock"
    visible: showing

    anchors {
        top: true
        right: true
    }
    implicitWidth: 400
    implicitHeight: Math.max(56, toastCol.implicitHeight + 20)
    margins.right: 10
    margins.top: Theme.barHeight + 8
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:rice-toast"

    Timer {
        id: toastTimer
        onTriggered: Notifs.closeToast(false)
    }

    onEntryChanged: {
        if (entry) {
            const defaultMs = entry.urgency === 2 ? 6000 : (entry.urgency === 0 ? 2000 : 4000);
            const ms = entry.expireTimeout > 0
                ? Math.max(2000, Math.min(15000, entry.expireTimeout))
                : defaultMs;
            toastTimer.interval = ms;
            toastTimer.restart();
        } else {
            toastTimer.stop();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.popupBg
        border.width: 1
        border.color: root.entry && root.entry.urgency === 2 ? Theme.danger : Theme.border

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
            id: toastCol
            anchors.left: iconChip.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.entry ? root.entry.appName : ""
                elide: Text.ElideRight
                visible: text !== ""
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: root.entry ? (root.entry.summary !== "" ? root.entry.summary : root.entry.appName) : ""
                elide: Text.ElideRight
                color: root.entry && root.entry.urgency === 2 ? Theme.danger : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                text: root.entry ? root.entry.body : ""
                elide: Text.ElideRight
                visible: text !== ""
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.closeToast(true)
        }
    }
}
