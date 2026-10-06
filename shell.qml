//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "core"
import "bar"
import "popups"
import "standalone"

ShellRoot {
    // starts the screen-time accumulator (singleton — lazily created, so it
    // needs an explicit first touch; it must count all day even if the
    // dashboard is never opened)
    Component.onCompleted: ScreenTime.init()

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

    // mainMod+W — the slanted wallpaper picker. NOT a bar feature (it's a
    // fullscreen desktop tool), so it registers under its own appid instead
    // of qs-bar. Bind line for the user's Lua config:
    // hl.bind(mainMod .. " + W", hl.dsp.global("qs:wallpaper-switcher"))
    GlobalShortcut {
        appid: "qs"
        name: "wallpaper-switcher"
        description: "Toggle the wallpaper picker"
        onPressed: Popups.toggle("wall")
    }

    // mainMod+V — clipboard history panel (cliphist backend, rofi picker
    // replacement). Standalone fullscreen panel (not a bar feature — its own
    // appid), centered on screen by the instance itself. Bind line:
    // hl.bind("SUPER + V", hl.dsp.global("qs:clipboard"))
    GlobalShortcut {
        appid: "qs"
        name: "clipboard"
        description: "Toggle the clipboard history panel"
        onPressed: Popups.toggle("clip")
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

    // Palette overlay: reads the matugen-generated colors.css — written into
    // THIS repo by the [templates.quickshell] block of
    // ~/.config/matugen/config.toml (the old ~/.config/waybar/colors.css
    // path is retired) — and feeds Theme; watchChanges re-applies it live on
    // every wallpaper change (matugen regenerates the file).
    FileView {
        path: Quickshell.env("HOME") + "/Documents/Dev/quickshell_rice/colors.css"
        watchChanges: true
        blockLoading: true
        printErrors: true
        // NB: FileView's public `text` is a FUNCTION (it shadows the internal
        // property) — call it, or you hand the parser a function object and it
        // silently finds no colors. watchChanges alone only fires fileChanged
        // without re-reading — reload() explicitly, then onLoaded re-applies.
        onFileChanged: reload()
        onLoaded: Theme.applyPaletteCss(text())
    }

    // toast banner (single instance, default screen)
    Toast {}

    // volume/mic/brightness OSD (service-driven, Overlay layer)
    Osd {}

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }

    // slanted wallpaper picker (single instance, default screen). Declared
    // AFTER the bar so its (invisible) input shield stacks above the bar,
    // same as the other popups: clicking a pill closes the picker first.
    Wallswitch {}

    // clipboard history panel (standalone, screen-centered, not a bar feature)
    ClipboardPopup {}

    // session lock screen (hyprlock replacement). Inert until something sets
    // LockState.engaged (qs-bar:lock shortcut / hypridle via `hyprctl eval`
    // / PowerPopup). GlobalShortcut + PAM live inside the component.
    Lockscreen {}
}
