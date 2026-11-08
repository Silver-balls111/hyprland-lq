import QtQuick
import "../core"

// 4-bar signal strength indicator (strength: 0..1, as returned by
// Quickshell's WifiNetwork.signalStrength)
Item {
    id: root

    property real strength: 0
    property color color: Theme.fg
    readonly property int bars: strength >= 0.75 ? 4 : strength >= 0.5 ? 3 : strength >= 0.25 ? 2 : strength >= 0.08 ? 1 : 0

    width: 14
    height: 12

    Row {
        anchors.bottom: parent.bottom
        spacing: 1.6
        Repeater {
            model: 4
            Rectangle {
                width: 2.4
                height: 3.5 + index * 2.6
                radius: 1.2
                anchors.bottom: parent.bottom
                color: root.color
                opacity: index < root.bars ? 1 : 0.25
            }
        }
    }
}
