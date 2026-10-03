import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

// Themed dropdown menu for a tray item, rendered from its DBusMenu via
// QsMenuOpener so it follows the bar's color scheme. One level of submenu
// drill-down with a back row.
PanelWindow {
    id: root

    property var barWindow: null
    property int anchorX: 0
    property var menuHandle: null
    // stack of parent handles for submenu navigation
    property var stack: []
    readonly property string popupName: "tray"

    function openFor(handle, x) {
        menuHandle = handle;
        stack = [];
        anchorX = x;
    }

    onVisibleChanged: {
        if (!root.visible && Popups.active === root.popupName) {
            Popups.lastDismiss = Date.now();
            Popups.active = "";
        }
    }

    Connections {
        target: Popups
        function onActiveChanged() {
            root.visible = (Popups.active === root.popupName);
        }
    }

    Component.onCompleted: visible = (Popups.active === popupName)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    visible: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:rice-traymenu"

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    // shield: click anywhere outside the menu closes it
    MouseArea {
        anchors.fill: parent
        onClicked: Popups.close()
        onWheel: wheel => wheel.accepted = false
    }

    Item {
        id: panelArea
        x: Math.max(8, root.anchorX - width)
        y: Theme.barHeight + 6
        width: 280
        height: body.height

        Rectangle {
            id: body
            width: parent.width
            implicitHeight: Math.min(menuList.count, 5) * 36 + 20
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.border
            clip: true

            ListView {
                id: menuList
                anchors.fill: parent
                anchors.margins: 10
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

                model: opener.children

                delegate: Item {
                    id: menuRow
                    required property var modelData

                    width: menuList.width
                    height: menuRow.modelData.isSeparator ? 9 : 34

                    Rectangle {
                        visible: menuRow.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.track
                    }

                    Rectangle {
                        visible: !menuRow.modelData.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: entryMa.containsMouse && menuRow.modelData.enabled ? Theme.rowHover : "transparent"
                    }

                    Row {
                        visible: !menuRow.modelData.isSeparator
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Item {
                            width: 14
                            height: parent.height
                            IconImage {
                                anchors.centerIn: parent
                                visible: menuRow.modelData.icon !== ""
                                width: 14
                                height: 14
                                source: menuRow.modelData.icon
                                asynchronous: true
                            }
                            NIcon {
                                anchors.centerIn: parent
                                visible: menuRow.modelData.icon === "" && menuRow.modelData.checkState !== 0
                                name: "check"
                                iconSize: 13
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 14 - 20 - 26 - (menuRow.modelData.hasChildren ? 20 : 0)
                            text: menuRow.modelData.text
                            elide: Text.ElideRight
                            color: menuRow.modelData.enabled ? Theme.fg : Theme.fgMuted
                            opacity: menuRow.modelData.enabled ? 1 : 0.6
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        NIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: menuRow.modelData.hasChildren
                            name: "chevronRight"
                            iconSize: 13
                            iconColor: Theme.fgMuted
                        }
                    }

                    MouseArea {
                        id: entryMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !menuRow.modelData.isSeparator
                        cursorShape: menuRow.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!menuRow.modelData.enabled) return;
                            if (menuRow.modelData.hasChildren) {
                                root.stack.push(opener.menu);
                                opener.menu = menuRow.modelData;
                            } else {
                                menuRow.modelData.triggered();
                                Popups.close();
                            }
                        }
                    }
                }
            }

            // back row when inside a submenu
            Rectangle {
                visible: root.stack.length > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                height: 30
                radius: 10
                color: backMa.containsMouse ? Theme.rowHover : "transparent"
                z: 10

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    spacing: 8
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevronLeft"
                        iconSize: 13
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Back"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        opener.menu = root.stack.pop();
                    }
                }
            }
        }
    }
}
