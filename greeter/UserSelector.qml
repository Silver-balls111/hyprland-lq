import QtQuick
import QtQuick.Controls.Basic

// User dropdown panel — sits in the center column between the user pill and
// the password field. The Column skips it while hidden, so the password field
// only shifts down while the menu is open. Rows scroll when there are more
// than three users (delegates stay 14px narrower than the list so the
// attached scrollbar has its own lane, per repo convention).
Rectangle {
    id: root
    property var users: []
    property string activeUser: ""
    property bool open: false
    property color fgColor: Theme.fg
    property bool wallDark: false
    signal userSelected(string username)

    visible: open && users.length > 0
    width: 240
    height: userList.height + 10
    radius: Theme.popupRadius
    color: "transparent"
    border.width: 0

    ListView {
        id: userList
        x: 10
        y: 5
        width: parent.width - 20
        height: Math.min(3 * 44 + 2 * 4, root.users.length * 44 + Math.max(0, root.users.length - 1) * 4)
        clip: true
        model: root.users
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        delegate: Rectangle {
            required property var modelData
            required property int index

            width: userList.width - (userList.interactive ? 14 : 0)
            height: 44
            radius: 12
            readonly property bool isCurrent: root.activeUser === modelData.name
            readonly property bool isHovered: uMouse.containsMouse

            color: isCurrent
                ? (root.wallDark ? Qt.rgba(1, 1, 1, 0.22) : Theme.pillHover)
                : (isHovered ? (root.wallDark ? Qt.rgba(1, 1, 1, 0.12) : Theme.rowHover) : "transparent")

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 12

                // Avatar with fallback to initial letter
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Theme.userAvatarColor(modelData.name)
                        visible: uAvatar.imgStatus !== Image.Ready

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name !== "" ? modelData.name.charAt(0).toUpperCase() : "?"
                            color: "#f2f2f2"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }

                    RoundedImage {
                        id: uAvatar
                        anchors.fill: parent
                        rounding: 14
                        source: {
                            if (modelData.avatar) return GreeterState.fileUrl(modelData.avatar);
                            return Qt.resolvedUrl("assets/pfp.png");
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 64
                    elide: Text.ElideRight
                    text: modelData.gecos || modelData.name
                    color: root.fgColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }

                NIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    iconSize: 14
                    iconColor: root.fgColor
                    visible: isCurrent
                }
            }

            TapHandler {
                onTapped: {
                    root.userSelected(modelData.name);
                    root.open = false;
                }
            }

            MouseArea {
                id: uMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.userSelected(modelData.name);
                    root.open = false;
                }
            }
        }

        // Policy bound off actual scroll — ScrollBar.AsNeeded maps the bar
        // even when nothing overflows (phantom full-length handle, see the
        // bar's hard rule 6)
        ScrollBar.vertical: ScrollBar {
            policy: userList.contentHeight > userList.height
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
