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

        // Popups are created on demand and DESTROYED on close: an idle shell
        // carries no popup trees, and every open is a fresh window created
        // mid-open — RicePopup syncs initial visibility from Popups.active in
        // Component.onCompleted, so this is deterministic. Keep-forever +
        // remap was tried first and is FLAKY: after several other popup
        // windows had mapped/unmapped, a remapped surface sometimes never
        // appeared at all (hyprctl layers showed nothing; hit live 2/14
        // opens). Fresh creation avoids the remap path entirely; the
        // re-instantiation cost is ~ms (the engine caches compiled
        // components) and idle memory returns to zero on close.
        Loader {
            active: Popups.active === "clock"
            sourceComponent: DashPopup {
                clock: clockPill.clock
                barWindow: bar
                anchorX: clockPill.x + clockPill.width / 2
                centerOnAnchor: true
            }
        }

        Loader {
            active: Popups.active === "wifi"
            sourceComponent: WifiPopup {
                barWindow: bar
                anchorX: statusPill.x + statusPill.wifiRightX
            }
        }

        Loader {
            active: Popups.active === "bt"
            sourceComponent: BluetoothPopup {
                barWindow: bar
                anchorX: statusPill.x + statusPill.btRightX
            }
        }

        Loader {
            active: Popups.active === "power"
            sourceComponent: PowerPopup {
                barWindow: bar
                anchorX: statusPill.x + statusPill.powerRightX
            }
        }
    }
}
