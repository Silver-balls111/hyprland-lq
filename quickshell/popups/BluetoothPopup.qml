import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Bluetooth
import "../core"
import "../ui"

RicePopup {
    id: root

    popupName: "bt"
    panelWidth: 330
    keyNavEnabled: true // Tab/arrows navigate devices, Enter activates, Esc closes

    readonly property var adapter: Bluetooth.defaultAdapter

    // single source of the sorted device list (list model + keyboard nav)
    readonly property var sortedDevices: root.adapter
        ? [...root.adapter.devices.values]
            .sort((a, b) => (b.connected - a.connected)
                || (b.paired - a.paired)
                || a.name.localeCompare(b.name))
        : []

    // selected row index (keyboard nav)
    property int selIndex: 0

    // NB: Connections, not an onVisibleChanged override — a subclass handler
    // would shadow RicePopup's own visible-changed bookkeeping
    Connections {
        target: root
        function onVisibleChanged() {
            if (root.adapter) root.adapter.discovering = root.visible;
            if (root.visible) selIndex = 0;
        }
    }
    onSelIndexChanged: {
        devList.currentIndex = selIndex;
        if (devList.count > 0)
            devList.positionViewAtIndex(selIndex, ListView.Contain);
    }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_Tab:
            if (sortedDevices.length > 0) selIndex = (selIndex + 1) % sortedDevices.length;
            return;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            if (sortedDevices.length > 0) selIndex = (selIndex - 1 + sortedDevices.length) % sortedDevices.length;
            return;
        case Qt.Key_Home:
            selIndex = 0;
            return;
        case Qt.Key_End:
            selIndex = Math.max(0, sortedDevices.length - 1);
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (sortedDevices.length > 0) activate(sortedDevices[selIndex]);
            return;
        }
    }

    // list re-sorts/repopulates on every scan cycle — keep the selection in
    // range or Enter hits `undefined` and the highlight vanishes
    Connections {
        target: root
        function onSortedDevicesChanged() {
            if (selIndex >= root.sortedDevices.length)
                selIndex = Math.max(0, root.sortedDevices.length - 1);
        }
    }

    function activate(dev) {
        if (!dev) return; // selIndex was out of range (list just moved)
        if (dev.connected) {
            dev.disconnect();
        } else if (dev.paired) {
            dev.connect();
        } else {
            dev.pair();
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            NIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "bluetooth"
                iconSize: 16
            }
            Text {
                Layout.fillWidth: true
                text: "Bluetooth"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
            Toggle {
                Layout.alignment: Qt.AlignVCenter
                checked: root.adapter ? root.adapter.enabled : false
                onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.adapter === null
            text: "No Bluetooth adapter found"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            visible: root.adapter !== null && !root.adapter.enabled
            text: "Bluetooth is off"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            visible: root.adapter && root.adapter.enabled && root.adapter.devices.values.length === 0
            text: root.adapter && root.adapter.discovering ? "Searching for devices…" : "No devices"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            horizontalAlignment: Text.AlignHCenter
        }

        // ── device list (max 5 visible, scrolls) ──
        ListView {
            id: devList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(count, 5) * 42 - 2
            visible: root.adapter !== null && root.adapter.enabled && count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: count > 5
            ScrollBar.vertical: ScrollBar {
                // explicit policy — see NotifsPanel: AsNeeded shows the bar
                // even when the content doesn't overflow the view
                policy: devList.contentHeight > devList.height
                    ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: Theme.fg
                    opacity: 0.3
                }
                background: Item {}
            }

            model: ScriptModel {
                values: root.sortedDevices
            }

            delegate: Item {
                id: devRow
                required property var modelData
                required property int index

                // lane reserved only while the bar actually shows (rule 6)
                readonly property bool sbShown:
                    devList.contentHeight > devList.height
                width: devList.width - (sbShown ? 14 : 4)
                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: rowMa.containsMouse || index === root.selIndex
                        ? Theme.rowHover : "transparent"
                }

                NIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bluetooth"
                    iconSize: 15
                    iconColor: devRow.modelData.connected ? Theme.fg : Theme.fgMuted
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.right: rightIcons.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: devRow.modelData.name !== "" ? devRow.modelData.name : devRow.modelData.address
                    elide: Text.ElideRight
                    color: Theme.fg
                    opacity: devRow.modelData.paired ? 1 : 0.65
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }

                Row {
                    id: rightIcons
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: devRow.modelData.batteryAvailable && devRow.modelData.battery >= 0
                        text: {
                            const b = devRow.modelData.battery;
                            return Math.round(b <= 1 ? b * 100 : b) + "%";
                        }
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: devRow.modelData.connected
                        name: "check"
                        iconSize: 14
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(devRow.modelData)
                }
            }
        }
    }
}
