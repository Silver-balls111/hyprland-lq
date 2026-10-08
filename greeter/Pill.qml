import QtQuick

Rectangle {
    id: root
    property bool hovered: mouseArea.containsMouse
    property bool active: false
    default property alias content: innerRow.data
    property alias spacing: innerRow.spacing
    property int hpadding: 16
    signal clicked()

    implicitHeight: Theme.pillHeight
    implicitWidth: innerRow.implicitWidth + (hpadding * 2)
    radius: height / 2
    color: active ? Theme.pillHover : (hovered ? Theme.pillHover : Theme.pillBg)
    border.width: 1
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
