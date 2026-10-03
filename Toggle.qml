import QtQuick

Rectangle {
    id: root

    property bool checked: false
    signal clicked()

    width: 36
    height: 20
    radius: 10
    color: checked ? Theme.accent : Theme.track

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    Rectangle {
        id: knob
        width: 14
        height: 14
        radius: 7
        color: root.checked ? Theme.fg : "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3

        Behavior on x {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
