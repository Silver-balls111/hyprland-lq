import QtQuick

Rectangle {
    id: root
    property bool hovered: mouseArea.containsMouse
    property bool active: false
    default property alias content: innerRow.data
    property alias spacing: innerRow.spacing
    property int hpadding: 16
    // No fill/border at rest — used by the bottom-corner overlays (session,
    // power) so they sit directly on the wallpaper. Hover/active still tint
    // so the trigger stays discoverable and the open state is obvious.
    property bool transparent: false
    // True while the pill paints a fill (hover or open) — callers bind their
    // text/icon color to this to stay legible over the tint or the wallpaper.
    readonly property bool filled: active || hovered
    signal clicked()

    implicitHeight: Theme.pillHeight
    implicitWidth: innerRow.implicitWidth + (hpadding * 2)
    radius: height / 2
    color: filled ? Theme.pillHover : (transparent ? "transparent" : Theme.pillBg)
    border.width: (transparent && !filled) ? 0 : 1
    border.color: Theme.border

    Behavior on color { ColorAnimation { duration: 140 } }

    Row {
        id: innerRow
        anchors.centerIn: parent
        spacing: 8
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
