import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import "../core"
import "../ui"

RicePopup {
    id: root

    popupName: "power"
    panelWidth: 220
    grabKeys: true // letter keybinds (s/r/u/l/h/o) act while the popup is open
    // selected row index (keyboard nav: Tab/arrows move, Enter/Space activates)
    property int selIndex: 0
    // NB: Connections, not an onVisibleChanged override — a subclass handler
    // would shadow RicePopup's own visible-changed bookkeeping
    Connections {
        target: root
        function onVisibleChanged() {
            if (!root.visible) return;
            selIndex = 0;
            actionList.contentY = 0;
        }
    }
    onSelIndexChanged: {
        actionList.currentIndex = selIndex;
        if (actionList.count > 0)
            actionList.positionViewAtIndex(selIndex, ListView.Contain);
    }
    // wlogout-style: the matching letter triggers the action
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selIndex = (selIndex + 1) % actionList.count;
            return;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selIndex = (selIndex - 1 + actionList.count) % actionList.count;
            return;
        case Qt.Key_Home:
            selIndex = 0;
            return;
        case Qt.Key_End:
            selIndex = actionList.count - 1;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (actionList.count > 0) root.run(actionList.model[selIndex]);
            return;
        }
        const entry = actionList.model.find(m => m.key === event.text.toLowerCase());
        if (entry) root.run(entry);
    }

    // entries either carry a cmd (execDetached) or act: "lock" (engages the
    // in-shell Lockscreen via LockState — PAM flow verified against
    // /etc/pam.d/login, the same stack hyprlock uses)
    function run(entry) {
        Actions.syncGreetdWallpaper();
        Popups.close();
        if (entry.act === "lock") { LockState.engaged = true; return; }
        Quickshell.execDetached(entry.cmd);
    }

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
            // explicit policy — see NotifsPanel: AsNeeded shows the bar
            // even when the content doesn't overflow the view
            policy: actionList.contentHeight > actionList.height
                ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
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
            { icon: "lock", label: "Lock", key: "o", act: "lock" }
        ]

        delegate: Rectangle {
            id: actionRow
            required property var modelData
            required property int index

            // lane reserved only while the bar actually shows (rule 6)
            readonly property bool sbShown:
                actionList.contentHeight > actionList.height
            width: actionList.width - (sbShown ? 14 : 4)
            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            height: 40
            radius: 12
            color: rowMa.containsMouse || index === root.selIndex
                ? Theme.rowHover : "transparent"

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
                    font.pixelSize: Theme.textSize
                }
            }

            MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(actionRow.modelData)
            }
        }
    }
}
