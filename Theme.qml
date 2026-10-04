pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "JetBrains Mono"
    readonly property string nerdFont: "JetBrains Mono Nerd Font Propo"

    // bar pills (soft translucent pink so the wallpaper shows through)
    readonly property color pillBg: Qt.rgba(0.973, 0.886, 0.925, 0.88)
    readonly property color pillHover: Qt.rgba(0.988, 0.925, 0.949, 0.95)
    readonly property color popupBg: Qt.rgba(0.976, 0.898, 0.933, 0.97)

    // active workspace / highlights
    readonly property color accent: "#f7c2d1"
    readonly property color accentSoft: "#fad4de"
    // workspace that requested attention
    readonly property color urgent: "#f5bf9c"

    // text
    readonly property color fg: "#2b1526"
    readonly property color fgMuted: Qt.rgba(fg.r, fg.g, fg.b, 0.55)

    // misc
    readonly property color border: Qt.rgba(1, 1, 1, 0.35)
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.28)
    readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.18)
    readonly property color inputBg: Qt.rgba(1, 1, 1, 0.5)
    readonly property color archBlue: "#1793d1"
    readonly property color danger: "#c4586e"
    // column separator inside the dashboard popup
    readonly property color divider: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

    // metrics
    readonly property int barHeight: 46
    readonly property int pillHeight: 32
    readonly property int popupRadius: 18
}
