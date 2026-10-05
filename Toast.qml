import QtQuick
import Quickshell
import Quickshell.Wayland

// Toast stack — every notification shows its own banner at the top-right
// (newest on top, older ones pushed down), each retiring when its own
// deadline passes. Small mapped-only window (TooltipWindow pattern: no input
// masks on 0.3.1). Click a banner to expand/collapse the full body (its
// deadline freezes while expanded); the corner ✕ dismisses it.
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

    Column {
        id: stackCol
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.left: parent.left
        spacing: 8

        Repeater {
            model: Notifs.activeToasts

            delegate: Rectangle {
                id: toastCard
                required property var modelData
                readonly property bool urgent: modelData.urgency === 2

                // local mirror of the entry's expanded flag: toggling the LOCAL
                // property animates the height, and onExpandedChanged keeps the
                // entry in sync — mutating the entry alone is not reactive, and
                // reassigning the stack would rebuild the card mid-animation
                property bool expanded: modelData.expanded
                onExpandedChanged: {
                    modelData.expanded = expanded;
                    if (!expanded)
                        modelData.expiresAt = Math.max(modelData.expiresAt, Date.now() + 2000);
                }

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
                        text: toastCard.modelData.appName
                        elide: Text.ElideRight
                        visible: text !== ""
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: toastCard.modelData.summary !== "" ? toastCard.modelData.summary : toastCard.modelData.appName
                        elide: Text.ElideRight
                        color: urgent ? Theme.danger : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: toastCard.modelData.body
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
                    onClicked: toastCard.expanded = !toastCard.expanded
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
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismissToast(toastCard.modelData, true)
                    }
                }
            }
        }
    }
}
