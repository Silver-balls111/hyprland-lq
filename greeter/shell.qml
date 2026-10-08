//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // Touch Colors first so Theme's md3 bindings resolve on a cold start
    // (qmldir singletons are otherwise lazy and Theme can load first).
    Component.onCompleted: console.warn("greeter palette:", Colors.md3.secondary)

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            property var modelData
            screen: modelData

            anchors { left: true; right: true; top: true; bottom: true }
            exclusiveZone: -1
            color: "#000000"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell:greeter"

            Greeter {
                anchors.fill: parent
            }
        }
    }
}
