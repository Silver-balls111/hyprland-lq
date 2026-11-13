import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root
    property var sessions: []
    property var currentSession: null
    property bool open: false
    // Adaptive foregrounds supplied by the greeter (wallpaper luminance).
    // Only used at rest — once the pill tints on hover/open the dark-on-light
    // pair is correct again.
    property color fgColor: Theme.fg
    property color fgMutedColor: Theme.fgMuted
    signal sessionSelected(var session)

    width: open ? Math.max(triggerPill.implicitWidth, popup.width) : triggerPill.implicitWidth
    height: open ? (triggerPill.implicitHeight + 10 + popup.height) : triggerPill.implicitHeight

    // Trigger pill in bottom-left
    Pill {
        id: triggerPill
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        transparent: true
        active: root.open
        onClicked: root.open = !root.open

        readonly property color contentFg: filled ? Theme.fg : root.fgColor
        readonly property color contentFgMuted: filled ? Theme.fgMuted : root.fgMutedColor

        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "desktop"
            iconSize: 15
            iconColor: triggerPill.contentFg
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentSession ? root.currentSession.name : "Session"
            color: triggerPill.contentFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
        }

        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.open ? "chevronUp" : "chevronDown"
            iconSize: 12
            iconColor: triggerPill.contentFgMuted
        }
    }

    // Popup panel positioned above the trigger
    Rectangle {
        id: popup
        visible: root.open
        anchors.bottom: triggerPill.top
        anchors.bottomMargin: 10
        anchors.left: triggerPill.left
        width: Math.max(220, triggerPill.width + 40)
        height: Math.min(260, (root.sessions.length * 38 + Math.max(0, root.sessions.length - 1) * 4) + 20)
        radius: Theme.popupRadius
        color: Qt.rgba(0, 0, 0, 0.40)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        // Swallower mouse area to prevent click-through
        MouseArea {
            anchors.fill: parent
            onClicked: {} // consume click
        }

        ListView {
            id: sessionList
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4
            clip: true
            model: root.sessions
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                required property int index

                // Delegates shift out of the scrollbar lane only while the
                // list actually overflows (same lane convention as the bar)
                readonly property bool sbShown: sessionList.contentHeight > sessionList.height
                width: sessionList.width - (sbShown ? 14 : 0)
                height: 38
                radius: 12
                readonly property bool isSelected: root.currentSession && root.currentSession.name === modelData.name
                readonly property bool isHovered: itemMouse.containsMouse || itemTap.pressed

                color: isSelected
                    ? Qt.rgba(1, 1, 1, 0.22)
                    : (isHovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.type === "wayland" ? "wayland" : "x11"
                        iconSize: 14
                        iconColor: isSelected ? root.fgColor : root.fgMutedColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 50
                        elide: Text.ElideRight
                        text: modelData.name
                        color: root.fgColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }

                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        iconSize: 14
                        iconColor: root.fgColor
                        visible: isSelected
                    }
                }

                TapHandler {
                    id: itemTap
                    onTapped: {
                        root.sessionSelected(modelData);
                        root.open = false;
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.sessionSelected(modelData);
                        root.open = false;
                    }
                }
            }

            // Policy bound off actual scroll — AsNeeded showed a phantom
            // full-length handle when nothing overflows (hard rule 6)
            ScrollBar.vertical: ScrollBar {
                policy: sessionList.contentHeight > sessionList.height
                    ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                implicitWidth: 6
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: Theme.rowHover
                }
                background: Item {}
            }
        }
    }
}
