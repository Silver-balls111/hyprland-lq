import QtQuick

// Rounded "pill" container; declared children go into its inner row.
Rectangle {
    id: root

    default property alias content: contentRow.data
    property real hpadding: 14
    property real vpadding: 7
    property real spacing: 8
    property bool hoverable: true
    // x position of the inner row (for anchoring popups to specific items)
    readonly property real rowX: contentRow.x

    implicitHeight: contentRow.implicitHeight + vpadding * 2
    implicitWidth: contentRow.implicitWidth + hpadding * 2
    // uniform fixed height so every pill's top/bottom edges align in the bar
    // (content-driven heights drift apart with different fonts)
    height: Theme.pillHeight
    radius: height / 2
    color: hoverable && hover.hovered ? Theme.pillHover : Theme.pillBg

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.spacing
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.ArrowCursor
    }
}
