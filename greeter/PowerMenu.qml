import QtQuick
import QtQuick.Controls.Basic
import Quickshell

Item {
    id: root
    property bool open: false
    // Adaptive foreground supplied by the greeter (wallpaper luminance) — used
    // only at rest; the tinted hover/open fill restores the dark-on-light pair.
    property color fgColor: Theme.fg

    width: open ? Math.max(powerPill.implicitWidth, popup.width) : powerPill.implicitWidth
    height: open ? (powerPill.implicitHeight + 10 + popup.height) : powerPill.implicitHeight

    // Power action model
    readonly property var actions: [
        { label: "Power Off", icon: "power", key: "s", cmd: ["systemctl", "poweroff"] },
        { label: "Reboot", icon: "restart", key: "r", cmd: ["systemctl", "reboot"] },
        { label: "Suspend", icon: "suspend", key: "u", cmd: ["systemctl", "suspend"] },
        { label: "Hibernate", icon: "hibernate", key: "h", cmd: ["systemctl", "hibernate"] }
    ]

    function executeAction(act) {
        root.open = false;
        Quickshell.execDetached(act.cmd);
    }

    // Trigger pill in bottom-right
    Pill {
        id: powerPill
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        transparent: true
        active: root.open
        hpadding: 14
        onClicked: root.open = !root.open

        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "power"
            iconSize: 18
            iconColor: powerPill.filled ? Theme.fg : root.fgColor
        }
    }

    // Popup panel anchored above the power button
    Rectangle {
        id: popup
        visible: root.open
        anchors.bottom: powerPill.top
        anchors.bottomMargin: 10
        anchors.right: powerPill.right
        width: 190
        height: actionColumn.implicitHeight + 20
        radius: Theme.popupRadius
        color: Qt.rgba(0, 0, 0, 0.40)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        MouseArea {
            anchors.fill: parent
            onClicked: {} // swallower
        }

        Column {
            id: actionColumn
            anchors.fill: parent
            anchors.margins: 10
            spacing: 3

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData
                    required property int index

                    width: actionColumn.width
                    height: 38
                    radius: 12
                    readonly property bool isHovered: rowMouse.containsMouse || rowTap.pressed
                    color: isHovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        NIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            iconSize: 16
                            iconColor: modelData.key === "s" ? Theme.danger : root.fgColor
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: root.fgColor
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSize
                        }
                    }

                    TapHandler {
                        id: rowTap
                        onTapped: root.executeAction(modelData)
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.executeAction(modelData)
                    }
                }
            }
        }
    }
}
