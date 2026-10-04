import QtQuick
import Quickshell

RicePopup {
    id: root

    popupName: "clock"
    panelWidth: 300
    centerOnAnchor: true

    // set by Bar.qml
    property var clock: null

    // always open on the current month, even if the user browsed away last time
    onVisibleChanged: {
        if (visible && root.clock)
            viewDate = new Date(root.clock.date.getFullYear(), root.clock.date.getMonth(), 1);
    }

    property date viewDate: root.clock ? new Date(root.clock.date.getFullYear(), root.clock.date.getMonth(), 1) : new Date()

    function shiftMonth(delta) {
        root.viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1);
    }

    readonly property int weekStart: Qt.locale().firstDayOfWeek
    readonly property int daysInMonth: new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()
    readonly property int firstOffset: (new Date(viewDate.getFullYear(), viewDate.getMonth(), 1).getDay() - weekStart + 7) % 7
    // only as many week rows as the month needs (no blank filler row)
    readonly property int gridRows: Math.ceil((firstOffset + daysInMonth) / 7)

    function isToday(d) {
        return root.clock && d.getFullYear() === root.clock.date.getFullYear()
            && d.getMonth() === root.clock.date.getMonth() && d.getDate() === root.clock.date.getDate();
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clock ? Qt.formatDateTime(root.clock.date, "dddd, d MMMM yyyy") : ""
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Item {
            width: parent.width
            height: 28

            Rectangle {
                id: prevBtn
                width: 28
                height: 24
                radius: 8
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: prevMa.containsMouse ? Theme.accent : "transparent"
                NIcon {
                    anchors.centerIn: parent
                    name: "chevronLeft"
                    iconSize: 15
                }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(-1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            Rectangle {
                id: nextBtn
                width: 28
                height: 24
                radius: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: nextMa.containsMouse ? Theme.accent : "transparent"
                NIcon {
                    anchors.centerIn: parent
                    name: "chevronRight"
                    iconSize: 15
                }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        Row {
            width: parent.width
            Repeater {
                model: 7
                Item {
                    width: parent.width / 7
                    height: 20
                    Text {
                        anchors.centerIn: parent
                        text: Qt.locale().dayName((root.weekStart + index) % 7, Locale.ShortFormat).substring(0, 2).toUpperCase()
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            Repeater {
                model: root.gridRows * 7
                Item {
                    id: dayCell
                    readonly property int dayNum: index - root.firstOffset + 1
                    readonly property date cellDate: new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), dayNum)
                    readonly property bool valid: dayNum >= 1 && dayNum <= root.daysInMonth
                    readonly property bool today: valid && root.isToday(cellDate)

                    width: parent.width / 7
                    height: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: dayCell.today ? Theme.accent : (dayMa.containsMouse && dayCell.valid ? Theme.accentSoft : "transparent")
                    }
                    Text {
                        anchors.centerIn: parent
                        text: dayCell.valid ? dayCell.dayNum : ""
                        color: Theme.fg
                        opacity: dayCell.today ? 1 : 0.9
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: dayCell.today ? Font.Bold : Font.Medium
                    }
                    MouseArea {
                        id: dayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: dayCell.valid
                    }
                }
            }
        }
    }
}
