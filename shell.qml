//@ pragma UseQApplication
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
}
