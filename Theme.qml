pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Rubik"
    readonly property string nerdFont: "JetBrains Mono Nerd Font Propo"
    // single global text size — mirrors the waybar CSS 14.5px rule
    readonly property real textSize: 14.5

    // ---- palette ----
    // Defaults = the original pink rice. shell.qml watches the matugen-
    // generated colors.css (the same file waybar consumed) and feeds it to
    // applyPaletteCss(), so these switch with the wallpaper — live, via
    // watchChanges. Derived tones below stay formulaic on top of the roles.
    property color pillBg: Qt.rgba(0.973, 0.886, 0.925, 0.88)
    property color pillHover: Qt.rgba(0.988, 0.925, 0.949, 0.95)
    // opaque on purpose — popups must never go see-through (a compositor-side
    // layerrule pins opacity to 1 as well, see README layer rules)
    property color popupBg: Qt.rgba(0.976, 0.898, 0.933, 1.0)

    // active workspace / highlights
    property color accent: "#f7c2d1"
    property color accentSoft: "#fad4de"
    // workspace that requested attention
    property color urgent: "#f5bf9c"

    // text
    property color fg: "#2b1526"
    readonly property color fgMuted: Qt.rgba(fg.r, fg.g, fg.b, 0.55)

    // danger accents (critical notifications, destructive rows)
    property color danger: "#c4586e"

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

    // Feed with the contents of a matugen colors.css (@define-color lines).
    // Roles → Theme mapping: pill/popup bodies = secondary (translucent),
    // hover/active fills = secondary_fixed, text = on_secondary, urgent =
    // error, danger text = error_container (dark tone, readable on light
    // pills). Unknown/missing roles keep the current values.
    function applyPaletteCss(css) {
        const map = {};
        const re = /@define-color\s+([a-z0-9_]+)\s+(#[0-9a-fA-F]{6})/g;
        let m;
        while ((m = re.exec(css)) !== null) map[m[1]] = m[2];
        if (!map.secondary || !map.on_secondary) return;
        const rgb = hex => Qt.rgba(
            parseInt(hex.slice(1, 3), 16) / 255,
            parseInt(hex.slice(3, 5), 16) / 255,
            parseInt(hex.slice(5, 7), 16) / 255, 1);
        const sec = rgb(map.secondary);
        const fix = rgb(map.secondary_fixed || map.secondary);
        fg = map.on_secondary;
        pillBg = Qt.rgba(sec.r, sec.g, sec.b, 0.88);
        pillHover = Qt.rgba(fix.r, fix.g, fix.b, 0.95);
        popupBg = Qt.rgba(sec.r, sec.g, sec.b, 1.0);
        accent = fix;
        accentSoft = Qt.rgba(fix.r, fix.g, fix.b, 0.55);
        if (map.error) urgent = rgb(map.error);
        if (map.error_container) danger = rgb(map.error_container);
    }
}
