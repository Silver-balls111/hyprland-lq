import QtQuick
import Quickshell

// Clock-pill dashboard: calendar column (left) + notifications/media column
// (right), separated by a hairline. Fixed panel height — a playing media card
// only takes space from the notification list.
RicePopup {
    id: root

    popupName: "clock"
    centerOnAnchor: true
    panelWidth: 740
    panelHeight: 540

    // set by Bar.qml
    property var clock: null

    // always open on the current month, even if the user browsed away last time
    onVisibleChanged: {
        if (visible)
            calPanel.resetMonth();
    }

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        CalendarPanel {
            id: calPanel
            width: 310
            height: parent.height
            clock: root.clock
        }

        Rectangle {
            width: 1
            height: parent.height
            color: Theme.divider
        }

        NotifsPanel {
            width: parent.width - 310 - 1 - parent.spacing * 2
            height: parent.height
        }
    }
}
