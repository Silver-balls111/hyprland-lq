import QtQuick
import Quickshell
import "../core"

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

    // always open on the current month, even if the user browsed away last time;
    // opening the dashboard counts as having seen the notifications. The
    // system-usage section polls only while open. (NB: this handler shadows
    // RicePopup's onVisibleChanged — subclass handlers always do — which is
    // fine here because DashPopup needs none of the base bookkeeping; if that
    // ever changes, switch to a Connections like other subclasses.)
    onVisibleChanged: {
        if (visible) {
            calPanel.resetMonth();
            Notifs.markRead();
            sysUsage.start();
        } else {
            sysUsage.stop();
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Item {
            width: 310
            height: parent.height

            CalendarPanel {
                id: calPanel
                width: parent.width
                height: calPanel.contentHeight
                clock: root.clock
            }

            // profile/system section: pinned below the calendar's WORST-CASE
            // footprint (6 grid rows) and stretched to the column bottom, so
            // its position is stable while browsing 4/5/6-row months
            SystemUsage {
                id: sysUsage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: calPanel.maxContentHeight + 12
                anchors.bottom: parent.bottom
            }
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
