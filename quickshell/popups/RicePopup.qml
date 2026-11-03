import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

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
    // fixed panel height; 0 = auto-size from content (childrenRect)
    property int panelHeight: 0
    // keyboard navigation (Tab/arrows/Enter): popups that opt in grab the
    // keyboard while open so keys reach the panel without a click first
    property bool keyNavEnabled: false
    // power-menu style: while open, capture ALL keys so letter keybinds work
    property bool grabKeys: false
    // layer namespace (Hyprland layerrules match on it) — subclasses with
    // their own rules (e.g. dimaround) override this
    property string layerNamespace: "quickshell:popup"
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
    WlrLayershell.keyboardFocus: root.grabKeys || root.keyNavEnabled
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: root.layerNamespace

    onVisibleChanged: {
        if (!root.visible && Popups.active === root.popupName) {
            Popups.lastDismiss = Date.now();
            Popups.active = "";
        }
        if (visible) body.forceActiveFocus();
    }

    // hand keyboard focus back to the panel body (e.g. after a TextField
    // inside a subclass gave it away)
    function refocusBody() {
        body.forceActiveFocus();
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
        // clamp to the screen: a wide centered panel can otherwise hang off
        // either edge (anchorX is in bar-window coords; windows share origin)
        x: {
            const raw = root.centerOnAnchor ? root.anchorX - width / 2 : root.anchorX - width;
            const sw = root.screen ? root.screen.width : 0;
            if (sw <= 0) return raw;
            return Math.max(8, Math.min(raw, sw - width - 8));
        }
        y: Theme.barHeight
        width: root.panelWidth
        height: body.height

        // consume clicks that land on panel background / spacing / disabled
        // buttons so they never reach the shield below — a click inside the
        // panel must never close the popup (only outside clicks, Esc, or
        // re-clicking the trigger do). Sibling declared BEFORE body so it sits
        // under it: plain Rectangles don't accept clicks, so subclass content
        // above body gets clicks first, and only unconsumed clicks land here.
        // (Must NOT be a child of body: anchors.fill would feed childrenRect
        // and loop against the childrenRect-based implicitHeight.)
        MouseArea {
            anchors.fill: body
        }

        Rectangle {
            id: body
            width: parent.width
            implicitHeight: root.panelHeight > 0
                ? Math.min(root.panelHeight, (root.screen ? root.screen.height : 2160) - Theme.barHeight - 12)
                : childrenRect.y + childrenRect.height + 14
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
