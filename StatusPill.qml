import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Networking

// Right pill: system tray, volume, mic, wifi, bluetooth, battery, power.
Pill {
    id: root

    hpadding: 12
    spacing: 10
    hoverable: false

    property var barWindow: null   // tray menu parent
    property var tooltipHost: null // Bar provides the hover tooltip

    // right-edge x of wifi/bt/power items relative to the bar window
    // (popup panels anchor to these)
    readonly property real wifiRightX: rowX + wifiBox.x + wifiBox.width
    readonly property real btRightX: rowX + btBox.x + btBox.width
    readonly property real powerRightX: rowX + powerBox.x + powerBox.width

    // ── audio (PwObjectTracker binds .audio on the default nodes) ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real sinkVolume: sink?.audio?.volume ?? 0
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool micMuted: mic?.audio?.muted ?? true

    // ── wifi ──
    readonly property var wifiDevice: {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi) return list[i];
        return null;
    }
    function connectedNet() {
        if (!wifiDevice) return null;
        const nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++)
            if (nets[i].connected) return nets[i];
        return null;
    }

    // ── battery (UPower populates ~3s after launch; percentage is 0..1) ──
    readonly property var batt: UPower.displayDevice
    readonly property bool battVisible: batt && batt.ready && batt.isPresent
        && (batt.isLaptopBattery || batt.percentage > 0)
    readonly property bool battCharging: batt && batt.state === UPowerDeviceState.Charging

    function battTip() {
        if (!batt || !battVisible) return "";
        let s = Math.round(batt.percentage * 100) + "%";
        s += batt.state === UPowerDeviceState.Charging ? " — charging"
           : batt.state === UPowerDeviceState.Full ? " — full" : " — discharging";
        const t = battCharging ? batt.timeToFull : batt.timeToEmpty;
        if (t > 0) {
            const h = Math.floor(t / 3600), m = Math.round((t % 3600) / 60);
            s += " (" + h + ":" + String(m).padStart(2, "0") + (battCharging ? " to full" : " left") + ")";
        }
        return s;
    }

    // ── tooltips ──
    property string hoveredName: ""
    property Item hoveredAnchor: null
    function tipEnter(name, anchor) { hoveredName = name; hoveredAnchor = anchor; pushTip(); }
    function tipLeave(anchor) {
        if (hoveredAnchor === anchor) {
            hoveredName = ""; hoveredAnchor = null;
            if (tooltipHost) tooltipHost.hideTooltip(anchor);
        }
    }
    function pushTip() {
        if (hoveredName !== "" && tooltipHost && Popups.active === "")
            tooltipHost.showTooltip(hoveredAnchor, tipFor(hoveredName), root);
    }
    function tipFor(name) {
        if (name === "volume") {
            const pct = Math.round(root.sinkVolume * 100);
            return root.sinkMuted ? "Volume " + pct + "% (muted)" : "Volume " + pct + "%";
        }
        if (name === "wifi") {
            if (!Networking.wifiEnabled) return "Wi-Fi off";
            const net = connectedNet();
            return net ? net.name + " (" + net.signalStrength + "% signal)" : "Wi-Fi on — not connected";
        }
        if (name === "bt") {
            const a = Bluetooth.defaultAdapter;
            if (!a) return "No Bluetooth adapter";
            if (!a.enabled) return "Bluetooth off";
            const conn = a.devices.values.filter(d => d.connected);
            return conn.length > 0 ? conn.map(d => d.name).join("\n") : "Bluetooth on — not connected";
        }
        if (name === "battery") return battTip();
        return "";
    }
    onSinkVolumeChanged: pushTip()
    onSinkMutedChanged: pushTip()
    onMicMutedChanged: pushTip()
    onBattChargingChanged: pushTip()
    Connections {
        target: root.batt
        function onPercentageChanged() { root.pushTip(); }
    }
    Connections {
        target: Popups
        function onActiveChanged() { if (Popups.active === "") root.pushTip(); }
    }

    // ── system tray ──
    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayBox
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter

            width: 16
            height: 16

            IconImage {
                anchors.fill: parent
                source: trayBox.modelData.icon
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (trayBox.modelData.hasMenu) {
                        if (Popups.active === "tray" && trayMenu.menuHandle === trayBox.modelData.menu) {
                            Popups.close(); // re-click the same icon closes its menu
                        } else {
                            trayMenu.openFor(trayBox.modelData.menu,
                                             root.x + root.rowX + trayBox.x + trayBox.width);
                            Popups.active = "tray"; // closes any other open popup
                        }
                    } else {
                        trayBox.modelData.activate();
                    }
                }
                onWheel: wheel => trayBox.modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false)
            }
        }
    }

    TrayMenuPopup {
        id: trayMenu
        barWindow: root.barWindow
    }

    // ── volume ──
    Row {
        id: volBox
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.sinkMuted ? "volumeMuted" : (root.sinkVolume < 0.5 ? "volumeLow" : "volumeHigh")
            iconSize: 15
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            horizontalAlignment: Text.AlignLeft
            text: Math.round(root.sinkVolume * 100) + "%"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        TapHandler {
            onTapped: if (root.sink?.audio) root.sink.audio.muted = !root.sinkMuted
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                if (!root.sink?.audio) return;
                const step = ev.angleDelta.y > 0 ? 0.01 : -0.01;
                const v = Math.max(0, Math.min(1.5, root.sinkVolume + step));
                root.sink.audio.volume = Math.round(v * 100) / 100;
            }
        }
    }

    // ── microphone ──
    Item {
        id: micBox
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        NIcon {
            anchors.centerIn: parent
            name: root.micMuted ? "micOff" : "mic"
            iconSize: 15
        }
        TapHandler {
            onTapped: if (root.mic?.audio) root.mic.audio.muted = !root.micMuted
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                if (!root.mic?.audio) return;
                const step = ev.angleDelta.y > 0 ? 0.02 : -0.02;
                const v = Math.max(0, Math.min(1, (root.mic?.audio?.volume ?? 1) + step));
                root.mic.audio.volume = Math.round(v * 100) / 100;
            }
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ── wifi ──
    Item {
        id: wifiBox
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        NIcon {
            anchors.centerIn: parent
            name: Networking.wifiEnabled ? "wifi" : "wifiOff"
            iconSize: 15
        }
        TapHandler {
            onTapped: Popups.toggle("wifi")
        }
        HoverHandler {
            onHoveredChanged: hovered ? root.tipEnter("wifi", wifiBox) : root.tipLeave(wifiBox)
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ── bluetooth ──
    Item {
        id: btBox
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        NIcon {
            anchors.centerIn: parent
            name: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? "bluetooth" : "bluetoothOff"
            iconSize: 15
        }
        TapHandler {
            onTapped: Popups.toggle("bt")
        }
        HoverHandler {
            onHoveredChanged: hovered ? root.tipEnter("bt", btBox) : root.tipLeave(btBox)
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ── battery ──
    Row {
        id: battBox
        anchors.verticalCenter: parent.verticalCenter
        visible: root.battVisible
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batt ? Math.round(root.batt.percentage * 100) + "%" : ""
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.battCharging ? "batteryCharging" : "battery"
            level: root.batt && root.battVisible ? root.batt.percentage : 0
            iconSize: 16
        }
        HoverHandler {
            onHoveredChanged: hovered ? root.tipEnter("battery", battBox) : root.tipLeave(battBox)
        }
    }

    // ── power ──
    Item {
        id: powerBox
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        NIcon {
            anchors.centerIn: parent
            name: "power"
            iconSize: 15
        }
        TapHandler {
            onTapped: Popups.toggle("power")
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
