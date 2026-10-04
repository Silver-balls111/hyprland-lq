//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    // ALT+X (bound in hyprland.conf as: bind = ALT, X, global, rice:powermenu)
    // toggles the power popup — the wlogout replacement workflow.
    GlobalShortcut {
        appid: "qs-bar"
        name: "powermenu"
        description: "Toggle the power menu"
        onPressed: Popups.toggle("power")
    }

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
