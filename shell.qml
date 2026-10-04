//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

ShellRoot {
    // mainMod+X (bound in the hyprland Lua config as:
    // hl.bind(mainMod .. " + X", hl.dsp.global("qs-bar:powermenu")))
    // toggles the power popup — the wlogout replacement workflow.
    GlobalShortcut {
        appid: "qs-bar"
        name: "powermenu"
        description: "Toggle the power menu"
        onPressed: Popups.toggle("power")
    }

    // mainMod+N — toggles the clock dashboard (calendar + notifications), same
    // pattern as the power menu. The user binds it in their Lua config, e.g.:
    // hl.bind(mainMod .. " + N", hl.dsp.global("qs-bar:notification"))
    GlobalShortcut {
        appid: "qs-bar"
        name: "notification"
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
