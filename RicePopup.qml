import QtQuick
import Quickshell
import Quickshell.Wayland

// Dropdown popup: a full-screen transparent layer-shell window ("shield")
// covering everything below the bar. Clicks on the shield background close it;
// the visible panel is positioned relative to the bar item that opened it.
// The bar itself stays clickable (shield starts below it).
PanelWindow {
    id: root

    property string popupName: ""
    property var barWindow: null
    // x (in bar-window coordinates) the panel anchors to
    property int anchorX: 0
    // true: panel centered on anchorX; false: panel's right edge at anchorX
    property bool centerOnAnchor: false
    property int panelWidth: 300
    // power-menu style: while open, capture ALL keys so letter keybinds work
    property bool grabKeys: false
    // forwarded from the focused body so subclasses can implement keybinds
    signal keyPressed(var event)

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
    WlrLayershell.keyboardFocus: root.grabKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:rice-popup"

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

    Component.onCompleted: {
        visible = (Popups.active === popupName);
    }

    // shield background: click anywhere outside the panel to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            Popups.lastDismiss = Date.now();
            Popups.close();
        }
    }

    default property alias content: body.data

    Item {
        id: panelArea
        x: root.centerOnAnchor ? root.anchorX - width / 2 : root.anchorX - width
        y: Theme.barHeight
        width: root.panelWidth
        height: body.height

        Rectangle {
            id: body
            width: parent.width
            implicitHeight: childrenRect.y + childrenRect.height + 14
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.border
            clip: true
            focus: true

            Keys.onEscapePressed: Popups.close()
            Keys.onPressed: event => root.keyPressed(event)
        }

    }
}
