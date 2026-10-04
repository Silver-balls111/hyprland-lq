import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Bluetooth

RicePopup {
    id: root

    popupName: "bt"
    panelWidth: 330

    readonly property var adapter: Bluetooth.defaultAdapter

    onVisibleChanged: if (adapter) adapter.discovering = visible

    function activate(dev) {
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
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: Theme.fg
                    opacity: 0.3
                }
                background: Item {}
            }

            model: ScriptModel {
                values: root.adapter
                    ? [...root.adapter.devices.values]
                        .sort((a, b) => (b.connected - a.connected)
                            || (b.paired - a.paired)
                            || a.name.localeCompare(b.name))
                    : []
            }

            delegate: Item {
                id: devRow
                required property var modelData

                width: devList.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: rowMa.containsMouse ? Theme.rowHover : "transparent"
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
