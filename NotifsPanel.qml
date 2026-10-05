import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Services.Mpris

// Notifications column of the dashboard: MPRIS player card(s) docked on top,
// notification history below (scrolls), DND + Clear footer. The media card only
// takes space from the list — the panel height is fixed by DashPopup.
Item {
    id: root

    // any player that isn't fully stopped (paused players stay visible)
    readonly property var activePlayers:
        Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── media cards ──
        Repeater {
            model: ScriptModel {
                values: root.activePlayers
            }

            delegate: Rectangle {
                id: playerCard
                required property var modelData
                readonly property var player: modelData

                Layout.fillWidth: true
                height: 76
                radius: 12
                color: Theme.rowHover

                Rectangle {
                    id: art
                    width: 48
                    height: 48
                    radius: 8
                    clip: true
                    color: Theme.inputBg
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        visible: playerCard.player.trackArtUrl !== ""
                        source: playerCard.player.trackArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    NIcon {
                        anchors.centerIn: parent
                        visible: playerCard.player.trackArtUrl === ""
                        name: "music"
                        iconSize: 22
                        iconColor: Theme.fgMuted
                    }
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 10
                    anchors.right: controls.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: playerCard.player.identity
                        elide: Text.ElideRight
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        text: playerCard.player.trackTitle !== "" ? playerCard.player.trackTitle : playerCard.player.identity
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        visible: playerCard.player.trackArtists !== ""
                        text: playerCard.player.trackArtists
                        elide: Text.ElideRight
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }

                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "prev", enabled: playerCard.player.canGoPrevious, action: () => playerCard.player.previous() },
                            { icon: playerCard.player.isPlaying ? "pause" : "play", enabled: playerCard.player.canTogglePlaying, action: () => playerCard.player.togglePlaying() },
                            { icon: "next", enabled: playerCard.player.canGoNext, action: () => playerCard.player.next() }
                        ]

                        delegate: Rectangle {
                            id: ctrlBtn
                            required property var modelData
                            readonly property bool usable: modelData.enabled

                            width: 26
                            height: 26
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: ctrlMa.containsMouse && usable ? Theme.accent : "transparent"
                            opacity: usable ? 1 : 0.35

                            NIcon {
                                anchors.centerIn: parent
                                name: ctrlBtn.modelData.icon
                                iconSize: 14
                            }
                            MouseArea {
                                id: ctrlMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: ctrlBtn.usable
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrlBtn.modelData.action()
                            }
                        }
                    }
                }
            }
        }

        // ── notification history (scrolls) ──
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: Theme.fg
                    opacity: 0.3
                }
                background: Item {}
            }

            model: Notifs.history

            delegate: Rectangle {
                id: notifRow
                required property var modelData
                required property int index

                width: notifList.width - 14
                height: 48
                radius: 12
                color: rowMa.containsMouse ? Theme.rowHover : "transparent"

                Rectangle {
                    id: iconChip
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.inputBg
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    NIcon {
                        anchors.centerIn: parent
                        name: "bell"
                        iconSize: 15
                        iconColor: Theme.fgMuted
                    }
                }

                Column {
                    anchors.left: iconChip.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: notifRow.modelData.summary !== "" ? notifRow.modelData.summary : notifRow.modelData.appName
                        elide: Text.ElideRight
                        color: notifRow.modelData.urgency === 2 ? Theme.danger : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        width: parent.width
                        visible: notifRow.modelData.body !== ""
                        text: notifRow.modelData.body
                        elide: Text.ElideRight
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize
                    }
                }

                // visual-only dismiss affordance — rowMa handles the click
                // (anywhere on the row removes), so it never flickers on hover
                NIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "xmark"
                    iconSize: 12
                    iconColor: Theme.fgMuted
                    opacity: rowMa.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.remove(notifRow.index)
                }
            }
        }

        // ── empty state ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: notifList.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 12

                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "bell"
                    iconSize: 42
                    iconColor: Theme.fgMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No Notifications"
                    color: Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
            }
        }

        // ── footer: DND + Clear ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Do Not Disturb"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }
            Toggle {
                Layout.alignment: Qt.AlignVCenter
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }
            Rectangle {
                id: clearBtn
                width: 56
                height: 26
                radius: 9
                color: clearMa.containsMouse ? Theme.accent : Theme.rowHover

                Text {
                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }
        }
    }
}
