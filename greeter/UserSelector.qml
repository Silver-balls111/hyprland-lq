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
    signal userSelected(string username)

    visible: open && users.length > 0
    width: 240
    height: userList.height + 20
    radius: Theme.popupRadius
    color: Theme.popupBg
    border.width: 1
    border.color: Theme.border

    ListView {
        id: userList
        x: 10
        y: 10
        width: parent.width - 20
        height: Math.min(contentHeight, 3 * 44 + 2 * 4)
        clip: true
        model: root.users
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        delegate: Rectangle {
            required property var modelData
            required property int index

            width: userList.width - 14
            height: 44
            radius: 12
            readonly property bool isCurrent: root.activeUser === modelData.name
            readonly property bool isHovered: uMouse.containsMouse

            color: isCurrent ? Theme.pillHover : (isHovered ? Theme.rowHover : "transparent")

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 12

                // Initial-letter avatar circle
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.userAvatarColor(modelData.name)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name !== "" ? modelData.name.charAt(0) : "?"
                        color: "#f2f2f2"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 64
                    elide: Text.ElideRight
                    text: modelData.gecos || modelData.name
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }

                NIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    iconSize: 14
                    iconColor: Theme.fg
                    visible: isCurrent
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

        ScrollBar.vertical: ScrollBar {
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
