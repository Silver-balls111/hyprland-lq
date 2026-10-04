import QtQuick
import QtQuick.Controls.Basic
import Quickshell

RicePopup {
    id: root

    popupName: "power"
    panelWidth: 220
    grabKeys: true // letter keybinds (s/r/u/l/h/o) act while the popup is open
    // wlogout-style: the matching letter triggers the action
    onKeyPressed: event => {
        const entry = actionList.model.find(m => m.key === event.text.toLowerCase());
        if (entry) root.run(entry.cmd);
    }

    function run(cmd) {
        Popups.close();
        Quickshell.execDetached(cmd);
    }

    onVisibleChanged: if (visible) actionList.contentY = 0

    ListView {
        id: actionList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        // 5 visible rows; the popup body sizes itself from this height
        height: Math.min(count, 5) * 42 - 2
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        interactive: count > 5
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

        // actions + keybinds match ~/.config/wlogout/layout
        model: [
            { icon: "power", label: "Power Off", key: "s", cmd: ["hyprshutdown", "--post-cmd", "systemctl poweroff"] },
            { icon: "restart", label: "Reboot", key: "r", cmd: ["hyprshutdown", "--post-cmd", "reboot"] },
            { icon: "suspend", label: "Suspend", key: "u", cmd: ["systemctl", "suspend"] },
            { icon: "logout", label: "Log Out", key: "l", cmd: ["hyprshutdown"] },
            { icon: "hibernate", label: "Hibernate", key: "h", cmd: ["systemctl", "hibernate"] },
            { icon: "lock", label: "Lock", key: "o", cmd: ["/bin/sh", "-c", "$HOME/.config/hypr/hyprlock/hyprlock-auto.sh"] }
        ]

        delegate: Rectangle {
            id: actionRow
            required property var modelData

            width: actionList.width
            height: 40
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
