import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../core"
import "../ui"

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
    // selected entry index (keyboard nav; separators/disabled entries skipped)
    property int selIndex: 0

    function openFor(handle, x) {
        menuHandle = handle;
        stack = [];
        anchorX = x;
        menuList.contentY = 0;
        resetSel();
    }

    function validEntry(i) {
        const items = opener.children.values;
        return i >= 0 && i < items.length && items[i]
            && !items[i].isSeparator && items[i].enabled;
    }

    function step(dir) {
        const items = opener.children.values;
        if (items.length === 0) return;
        let i = selIndex;
        for (let n = 0; n < items.length; n++) {
            i = (i + dir + items.length) % items.length;
            if (validEntry(i)) {
                selIndex = i;
                return;
            }
        }
    }

    function resetSel() {
        selIndex = 0;
        if (opener.children.values.length > 0 && !validEntry(0)) step(1);
    }

    function activateSelected() {
        const it = opener.children.values[selIndex];
        if (!validEntry(selIndex)) return;
        if (it.hasChildren) {
            root.stack.push(opener.menu);
            opener.menu = it;
            resetSel();
        } else {
            it.triggered();
            Popups.close();
        }
    }

    onSelIndexChanged: {
        menuList.currentIndex = selIndex;
        if (menuList.count > 0)
            menuList.positionViewAtIndex(selIndex, ListView.Contain);
    }
    onVisibleChanged: {
        if (!root.visible && Popups.active === root.popupName) {
            Popups.lastDismiss = Date.now();
            Popups.active = "";
        }
        if (visible) {
            resetSel();
            body.forceActiveFocus();
        }
    }

    Connections {
        target: opener
        function onChildrenChanged() {
            if (!root.validEntry(root.selIndex)) root.resetSel();
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
    // modal menu: exclusive keyboard while open (Tab/arrows/Enter/Backspace)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:traymenu"

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
        y: Theme.barHeight
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
            focus: true

            Keys.onEscapePressed: Popups.close()
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Down:
                case Qt.Key_Tab:
                    root.step(1);
                    break;
                case Qt.Key_Up:
                case Qt.Key_Backtab:
                    root.step(-1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.activateSelected();
                    break;
                case Qt.Key_Left:
                case Qt.Key_Backspace:
                    if (root.stack.length > 0) {
                        opener.menu = root.stack.pop();
                        root.resetSel();
                    }
                    break;
                }
            }

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
                    required property int index

                    width: menuList.width - 14
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
                        color: (entryMa.containsMouse || menuRow.index === root.selIndex)
                            && menuRow.modelData.enabled ? Theme.rowHover : "transparent"
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
                            font.pixelSize: Theme.textSize
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
                        font.pixelSize: Theme.textSize
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
