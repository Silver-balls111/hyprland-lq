import QtQuick

Text {
    id: root
    property string name: ""
    property real level: 0
    property real iconSize: 16
    property color iconColor: Theme.fg

    font.family: Theme.nerdFont
    font.pixelSize: iconSize
    color: iconColor
    text: Icons.glyph(name, level)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    width: iconSize
    height: iconSize
    topPadding: Icons.yOffset(name)
}
