import QtQuick
import Quickshell

// Center pill: stateful bell + time. Bell mirrors waybar's notification-module
// glyphs (none/notification/dnd variants); click opens the dashboard.
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
        // stateful bell from the user's waybar notification-module glyph set:
        // unread+DND → bellDnd, unread → bellRing, DND+quiet → bellSleep, quiet → bell
        name: Notifs.unread > 0 ? (Notifs.dnd ? "bellDnd" : "bellRing")
                                : (Notifs.dnd ? "bellSleep" : "bell")
        iconSize: 15
        iconColor: Notifs.unread > 0 ? Theme.fg : Theme.fgMuted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clockObj.date, "hh:mm AP")
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSize
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
