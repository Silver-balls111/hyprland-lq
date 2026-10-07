import QtQuick
import "../core"

// Icon rendered with the Nerd Font (glyphs from Icons.qml).
// Fixed square box so all icons align vertically; per-glyph y offsets from
// Icons.yOffset(name) compensate for differing font metrics.
Item {
    id: root

    property string name: ""
    property real iconSize: 16
    property color iconColor: Theme.fg
    // used by "battery"/"batteryCharging" (0..1); ignored by other icons
    property real level: -1

    width: iconSize
    height: iconSize

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Icons.yOffset(root.name)
        font.family: Theme.nerdFont
        font.pixelSize: root.iconSize
        text: Icons.glyph(root.name, root.level)
        color: root.iconColor
    }
}
