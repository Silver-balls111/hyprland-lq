import QtQuick
import Quickshell

// Center pill: clock + bell. Shows the calendar when hovered (or clicked).
Pill {
    id: root

    property alias clock: clockObj
    property var tooltipHost: null

    readonly property string tip: Qt.formatDateTime(clockObj.date, "ddd, d MMM yyyy")
    readonly property bool hovered: pillHover.hovered

    SystemClock {
        id: clockObj
        precision: SystemClock.Minutes
    }

    NIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: "clock"
        iconSize: 15
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clockObj.date, "hh:mm AP")
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    NIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: "bell"
        iconSize: 15
    }

    HoverHandler {
        id: pillHover
        onHoveredChanged: {
            if (root.tooltipHost) {
                if (hovered) root.tooltipHost.showTooltip(root, root.tip, root);
                else root.tooltipHost.hideTooltip(root);
            }
        }
    }
    onTipChanged: {
        if (pillHover.hovered && tooltipHost) tooltipHost.showTooltip(root, tip);
    }
    Connections {
        target: Popups
        function onActiveChanged() {
            if (Popups.active === "" && pillHover.hovered && root.tooltipHost)
                root.tooltipHost.showTooltip(root, root.tip, root);
        }
    }
    TapHandler {
        onTapped: Popups.toggle("clock")
    }

}
