import QtQuick
import QtQuick.Layouts
import Quickshell

RicePopup {
    id: root

    popupName: "power"
    panelWidth: 220

    function run(cmd) {
        Popups.close();
        Quickshell.execDetached(cmd);
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 2

        Repeater {
            model: [
                { icon: "lock", label: "Lock", cmd: ["hyprlock"] },
                { icon: "logout", label: "Log Out", cmd: ["hyprctl", "dispatch", "exit"] },
                { icon: "restart", label: "Reboot", cmd: ["systemctl", "reboot"] },
                { icon: "power", label: "Power Off", cmd: ["systemctl", "poweroff"] }
            ]

            delegate: Rectangle {
                id: actionRow
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 12
                color: rowMa.containsMouse ? Theme.rowHover : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 10
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: actionRow.modelData.icon
                        iconSize: 15
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionRow.modelData.label
                        color: actionRow.modelData.label === "Power Off" ? Theme.danger : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run(actionRow.modelData.cmd)
                }
            }
        }
    }
}
