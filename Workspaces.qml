import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Always shows at least minCount slots; extra slots jump to (create) that workspace.
Pill {
    id: root

    property int minCount: 5
    // Hyprland >= 0.56 replaced the flat dispatch syntax with a Lua one
    property bool luaIpc: true

    vpadding: 0
    spacing: 1
    hoverable: false

    Process {
        id: versionProbe
        command: ["hyprctl", "version"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /Hyprland (\d+)\.(\d+)/.exec(text);
                root.luaIpc = !(m && Number(m[2]) < 56);
            }
        }
    }
    Component.onCompleted: versionProbe.running = true

    function switchTo(id) {
        if (root.luaIpc) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        } else {
            Hyprland.dispatch("workspace " + id);
        }
    }

    // Hoisted so delegates can read the edge ids: a Repeater id is not
    // resolvable from delegates created through the Pill's content alias
    // (ReferenceError -> isLast silently false).
    readonly property var wsValues: {
        const real = [...Hyprland.workspaces.values].filter(w => w.id > 0);
        const byId = new Map(real.map(w => [w.id, w]));
        for (let i = 1; i <= root.minCount; i++) {
            if (!byId.has(i)) byId.set(i, { id: i, name: String(i) });
        }
        return [...byId.values()].sort((a, b) => a.id - b.id);
    }

    Repeater {
        model: ScriptModel {
            values: root.wsValues
        }

        delegate: Rectangle {
            id: wsCell

            required property var modelData
            readonly property bool isFirst: modelData.id === root.wsValues[0].id
            readonly property bool isLast: modelData.id === root.wsValues[root.wsValues.length - 1].id
            readonly property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
            readonly property bool isUrgent: modelData.urgent === true
            readonly property string label: {
                const name = modelData.name || "";
                return (name !== "" && name !== String(modelData.id)) ? name : String(modelData.id);
            }
            // fully transparent, same RGB as accentSoft so the color animation
            // doesn't dip through transparent black (dark shadow flicker)
            readonly property color idleColor: Qt.rgba(
                Theme.accentSoft.r, Theme.accentSoft.g, Theme.accentSoft.b, 0)

            // idle + hover share one width; the ACTIVE cell is wider
            // (waybar parity). Switching swaps the two widths between cells,
            // so the pill's total width stays constant for equal labels —
            // the small fill motion mid-switch is subtle and waybar has it too.
            width: wsCell.isActive ? Math.max(44, wsLabel.implicitWidth + 36)
                                   : Math.max(34, wsLabel.implicitWidth + 26)
            height: Theme.pillHeight
            radius: height / 2
            color: isActive ? Theme.accent
                 : isUrgent ? Theme.urgent
                 : cellHover.hovered ? Theme.accentSoft : idleColor

            // only the ACTIVE fill bleeds into the pill's hpadding so it
            // reaches the pill's rounded cap; hover stays number-sized
            Rectangle {
                visible: wsCell.isFirst
                opacity: wsCell.isActive ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 130 }
                }
                x: -root.hpadding
                width: wsCell.height
                height: wsCell.height
                radius: width / 2
                color: wsCell.color
            }
            Rectangle {
                visible: wsCell.isLast
                opacity: wsCell.isActive ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 130 }
                }
                x: wsCell.width - wsCell.height + root.hpadding
                width: wsCell.height
                height: wsCell.height
                radius: width / 2
                color: wsCell.color
            }

            Behavior on color {
                ColorAnimation { duration: 130 }
            }
            Behavior on width {
                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
            }

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: wsCell.label
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }

            HoverHandler {
                id: cellHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.switchTo(wsCell.modelData.id)
            }
        }
    }
}
