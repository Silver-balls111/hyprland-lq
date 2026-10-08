pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Rubik"
    readonly property string nerdFont: "JetBrains Mono Nerd Font Propo"
    readonly property real textSize: 14.5

    // Same role mapping as quickshell/core/Theme.qml — Colors FileView-watches
    // matugen's colors.json (live under $HOME in preview, /var/cache/greetd
    // on the real greeter). Until that file exists the md3 strings are
    // "transparent" and the pink-rice snapshot fallbacks keep us renderable.
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
    // opaque — popups must never go see-through (matches the bar)
    readonly property color popupBg: secondary

    readonly property color accent: secondaryFixed
    readonly property color accentSoft: Qt.rgba(secondaryFixed.r, secondaryFixed.g, secondaryFixed.b, 0.55)
    readonly property color urgent: error

    readonly property color fg: onSecondary
    readonly property color fgMuted: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color danger: errorContainer

    readonly property color border: Qt.rgba(1, 1, 1, 0.35)
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.28)
    readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.18)
    readonly property color inputBg: Qt.rgba(1, 1, 1, 0.5)
    readonly property color divider: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

    readonly property int pillHeight: 40
    readonly property int popupRadius: 18

    // Deterministic muted dark tone per username — the initial-letter avatar
    // circles (light letter on a dark circle works on any wallpaper)
    function userAvatarColor(name) {
        let h = 0;
        const n = name ? name : "?";
        for (let i = 0; i < n.length; i++) h = (h * 31 + n.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360, 0.32, 0.32, 1.0);
    }
}
