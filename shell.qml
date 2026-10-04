//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

ShellRoot {
    // ALT+X (bound in hyprland config as: hl.bind("ALT + X", hl.dsp.global("qs-bar:powermenu")))
    // toggles the power popup — the wlogout replacement workflow.
    GlobalShortcut {
        appid: "qs-bar"
        name: "powermenu"
        description: "Toggle the power menu"
        onPressed: Popups.toggle("power")
    }

    // SUPER+N — replaces the old swaync toggle bind:
    // hl.bind("SUPER + N", hl.dsp.global("qs-bar:dashboard"))
    GlobalShortcut {
        appid: "qs-bar"
        name: "dashboard"
        description: "Toggle the clock dashboard (calendar + notifications)"
        onPressed: Popups.toggle("clock")
    }

    // The notification daemon — replaces swaync. Instantiated once here at the
    // shell root (NOT per-screen): only one process can own
    // org.freedesktop.Notifications, and swaync must not be running.
    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => Notifs.push(notification)
    }

    // toast banner (single instance, default screen)
    Toast {}

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
