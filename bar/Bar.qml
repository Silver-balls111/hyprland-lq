import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"
import "../popups"

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:bar"

    function showTooltip(item, text, yItem) {
        tooltipWindow.show(item, text, yItem);
    }
    function hideTooltip(item) {
        tooltipWindow.hide(item);
    }
    TooltipWindow {
        id: tooltipWindow
    }

    Item {
        anchors.fill: parent

        Workspaces {
            id: wsPill
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.left: parent.left
            anchors.leftMargin: 14
        }

        ClockPill {
            id: clockPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 5
            tooltipHost: bar
        }

        StatusPill {
            id: statusPill
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 5
            tooltipHost: bar
            barWindow: bar
        }

        DashPopup {
            clock: clockPill.clock
            barWindow: bar
            anchorX: clockPill.x + clockPill.width / 2
            centerOnAnchor: true
        }

        WifiPopup {
            barWindow: bar
            anchorX: statusPill.x + statusPill.wifiRightX
        }

        BluetoothPopup {
            barWindow: bar
            anchorX: statusPill.x + statusPill.btRightX
        }

        PowerPopup {
            barWindow: bar
            anchorX: statusPill.x + statusPill.powerRightX
        }
    }
}
