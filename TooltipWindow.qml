import QtQuick
import Quickshell
import Quickshell.Wayland

// Small floating window that renders one hover tooltip below a bar pill.
// Sized to the tooltip and only mapped while it is showing, so it never
// interferes with click routing (a full-screen overlay with an empty input
// region is not reliable — quickshell 0.3.1 may ignore the mask).
PanelWindow {
    id: root

    property string text: ""
    property Item anchorItem: null
    property Item yItem: null

    readonly property bool showing: text !== "" && Popups.active === ""
    visible: showing

    anchors {
        top: true
        left: true
    }
    implicitWidth: tooltipLabel.implicitWidth + 22
    implicitHeight: tooltipLabel.implicitHeight + 12
    margins.left: 0
    margins.top: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:rice-tooltip"

    function show(item, tip, bottomItem) {
        anchorItem = item;
        yItem = bottomItem || null;
        text = tip;
        const px = item.mapToItem(null, item.width / 2, 0).x;
        const py = (bottomItem || item).mapToItem(null, 0, (bottomItem || item).height).y;
        root.margins.left = Math.max(8, Math.round(px - root.implicitWidth / 2));
        root.margins.top = Math.round(py) + 6;
    }
    function hide(item) {
        if (anchorItem === item) {
            anchorItem = null;
            yItem = null;
            text = "";
        }
    }

    Rectangle {
        id: tooltip
        anchors.fill: parent
        radius: 10
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.border

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: root.text
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
