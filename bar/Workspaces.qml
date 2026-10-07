import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"
import "../ui"

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

    // Hoisted so the min-5 padding + sorting is computed in one place:
    // delegates read `root.wsValues` (a Repeater id is not resolvable from
    // delegates created through the Pill's content alias).
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

            // ONE width for every state: switching workspaces animates color
            // only, and the pill resizes exclusively when the workspace COUNT
            // changes (a 6th+ slot appears). A wider active cell + width
            // animation was implemented and reverted twice — do not re-add it.
            width: Math.max(34, wsLabel.implicitWidth + 26)
            height: Theme.pillHeight
            radius: height / 2
            color: isActive ? Theme.accent
                 : isUrgent ? Theme.urgent
                 : cellHover.hovered ? Theme.accentSoft : idleColor

            Behavior on color {
                ColorAnimation { duration: 130 }
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
