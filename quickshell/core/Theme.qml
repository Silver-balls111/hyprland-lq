pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Rubik"
    readonly property string nerdFont: "JetBrains Mono Nerd Font Propo"
    // single global text size — mirrors the waybar CSS 14.5px rule
    readonly property real textSize: 14.5

    // ---- palette ----
    // Source: the Colors singleton (core/Colors.qml), which FileView-watches
    // the matugen-generated colors.json (md3 roles; see the
    // [templates.quickshell] block in ~/.config/matugen/config.toml). Until
    // matugen's first run the md3 strings are "transparent" — the fallbacks
    // below (a snapshot of a previously generated scheme) keep the shell
    // renderable. Roles → Theme mapping: pill/popup bodies = secondary
    // (translucent), hover/active fills = secondary_fixed, text =
    // on_secondary, urgent = error, danger text = error_container (dark tone,
    // readable on light pills). Derived tones stay formulaic on top.
    readonly property color secondary: Colors.md3.secondary !== "transparent"
        ? Colors.md3.secondary : "#c1c6dd"
    readonly property color secondaryFixed: Colors.md3.secondary_fixed !== "transparent"
        ? Colors.md3.secondary_fixed : "#dde2f9"
    readonly property color onSecondary: Colors.md3.on_secondary !== "transparent"
        ? Colors.md3.on_secondary : "#2a3042"
    readonly property color error: Colors.md3.error !== "transparent"
        ? Colors.md3.error : "#ffb4ab"
    readonly property color errorContainer: Colors.md3.error_container !== "transparent"
        ? Colors.md3.error_container : "#93000a"

    readonly property color pillBg: Qt.rgba(secondary.r, secondary.g, secondary.b, 0.88)
    readonly property color pillHover: Qt.rgba(secondaryFixed.r, secondaryFixed.g, secondaryFixed.b, 0.95)
    // opaque on purpose — popups must never go see-through (a compositor-side
    // layerrule pins opacity to 1 as well, see README layer rules)
    readonly property color popupBg: secondary

    // active workspace / highlights
    readonly property color accent: secondaryFixed
    readonly property color accentSoft: Qt.rgba(secondaryFixed.r, secondaryFixed.g, secondaryFixed.b, 0.55)
    // workspace that requested attention
    readonly property color urgent: error

    // text
    readonly property color fg: onSecondary
    readonly property color fgMuted: Qt.rgba(fg.r, fg.g, fg.b, 0.55)

    // danger accents (critical notifications, destructive rows)
    readonly property color danger: errorContainer

    // misc sheens / overlays — deliberately fixed whites or fg-derived so they
    // work on any palette hue without their own matugen role
    readonly property color border: Qt.rgba(1, 1, 1, 0.35)
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.28)
    readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.18)
    readonly property color inputBg: Qt.rgba(1, 1, 1, 0.5)
    readonly property color divider: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

    // metrics
    readonly property int barHeight: 46
    readonly property int pillHeight: 36
    readonly property int popupRadius: 18
    readonly property int osdHeight: 52
}
