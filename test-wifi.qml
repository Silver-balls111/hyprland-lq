import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {
            property var modelData
            screen: modelData
        }
    }
    Timer { interval: 1500; running: true; onTriggered: Popups.active = "wifi" }
}
