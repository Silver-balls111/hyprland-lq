import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Networking

RicePopup {
    id: root

    popupName: "wifi"
    panelWidth: 330

    readonly property var wifiDevice: {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi) return list[i];
        return null;
    }

    property var pending: null

    onVisibleChanged: {
        if (wifiDevice) wifiDevice.scannerEnabled = visible;
        if (!visible) pending = null;
    }
    onWifiDeviceChanged: if (wifiDevice) wifiDevice.scannerEnabled = visible

    function activate(net) {
        if (net.connected) {
            net.disconnect();
            return;
        }
        if (net.known || net.security === WifiSecurityType.Open) {
            pending = null;
            net.connect();
        } else {
            pending = net;
            pwField.text = "";
            pwField.forceActiveFocus();
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
                name: "wifi"
                iconSize: 16
            }
            Text {
                Layout.fillWidth: true
                text: "Wi-Fi"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Toggle {
                Layout.alignment: Qt.AlignVCenter
                checked: Networking.wifiEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        // ── password prompt ──
        Rectangle {
            Layout.fillWidth: true
            visible: root.pending !== null
            implicitHeight: pwCol.implicitHeight + 16
            radius: 12
            color: Theme.inputBg

            ColumnLayout {
                id: pwCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Password for " + (root.pending ? root.pending.name : "")
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        echoMode: TextInput.Password
                        placeholderText: "password"
                        placeholderTextColor: Theme.fgMuted
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        background: Rectangle {
                            radius: 9
                            color: "#ffffff"
                            opacity: 0.75
                        }
                        onAccepted: connectBtn.action()
                    }
                    Rectangle {
                        id: connectBtn
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 30
                        radius: 9
                        color: Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.action()
                        }
                        function action() {
                            if (root.pending && pwField.text.length > 0)
                                root.pending.connectWithPsk(pwField.text);
                            root.pending = null;
                        }
                    }
                }
            }
        }

        // ── hints ──
        Text {
            Layout.fillWidth: true
            visible: root.wifiDevice === null
            text: Networking.wifiHardwareEnabled ? "No Wi-Fi device found" : "Wi-Fi is hard blocked (rfkill)"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            visible: root.wifiDevice !== null && !Networking.wifiEnabled
            text: "Wi-Fi is off"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }

        // ── network list (max 5 visible, scrolls) ──
        ListView {
            id: netList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(count, 5) * 40 - 2
            visible: root.wifiDevice !== null && Networking.wifiEnabled && count > 0
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
                values: root.wifiDevice
                    ? [...root.wifiDevice.networks.values]
                        .sort((a, b) => (b.connected - a.connected)
                            || (b.signalStrength - a.signalStrength)
                            || a.name.localeCompare(b.name))
                    : []
            }

            delegate: Item {
                id: netRow
                required property var modelData

                width: netList.width
                height: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: rowMa.containsMouse ? Theme.rowHover : "transparent"
                }

                SignalBars {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    strength: netRow.modelData.signalStrength
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.right: rightIcons.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: netRow.modelData.name !== "" ? netRow.modelData.name : "<hidden>"
                    elide: Text.ElideRight
                    color: Theme.fg
                    opacity: netRow.modelData.connected ? 1 : 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: netRow.modelData.connected ? Font.Bold : Font.Medium
                }

                Row {
                    id: rightIcons
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: netRow.modelData.security !== WifiSecurityType.Open
                        name: "lock"
                        iconSize: 11
                        iconColor: Theme.fgMuted
                    }
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: netRow.modelData.connected
                        name: "check"
                        iconSize: 14
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(netRow.modelData)
                }
            }
        }
    }
}
