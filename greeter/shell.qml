//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    // Touch Colors first so Theme's md3 bindings resolve on a cold start
    // (qmldir singletons are otherwise lazy and Theme can load first).
    Component.onCompleted: console.warn("greeter palette:", Colors.md3.secondary)

    Variants {
        model: Quickshell.screens

        FloatingWindow {
            id: win
            property var modelData
            screen: modelData

            fullscreen: true
            color: "#000000"

            Greeter {
                anchors.fill: parent
            }
        }
    }
}
