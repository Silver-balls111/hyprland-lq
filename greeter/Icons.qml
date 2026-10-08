pragma Singleton
import QtQml

QtObject {
    function glyph(name, level) {
        if (name === "battery") return batteryGlyph(level, false);
        if (name === "batteryCharging") return batteryGlyph(level, true);
        return glyphs[name] || "";
    }

    function yOffset(name) {
        return yOffsets[name] || 0;
    }

    readonly property var yOffsets: {
        "power": -1,
        "restart": 0,
        "suspend": 0,
        "lock": 0
    }

    function batteryGlyph(level, charging) {
        const l = Math.max(0, Math.min(1, level < 0 ? 1 : level));
        if (charging) {
            const c = [0xF089C, 0xF0086, 0xF0087, 0xF0088, 0xF089D, 0xF0089, 0xF089E, 0xF008A, 0xF008B, 0xF0085];
            return String.fromCodePoint(c[Math.min(c.length - 1, Math.floor(l * 10))]);
        }
        const d = [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079];
        return String.fromCodePoint(d[Math.min(d.length - 1, Math.floor(l * 10))]);
    }

    readonly property var glyphs: {
        "power": String.fromCodePoint(0xF0425),
        "restart": String.fromCodePoint(0xF0709),
        "suspend": String.fromCodePoint(0xF04B2),
        "hibernate": String.fromCodePoint(0xE7FC),
        "logout": String.fromCodePoint(0xF05FD),
        "lock": String.fromCodePoint(0xF033E),
        "user": String.fromCodePoint(0xF007),
        "users": String.fromCodePoint(0xF0C0),
        "desktop": String.fromCodePoint(0xF108),
        "wayland": String.fromCodePoint(0xF108),
        "x11": String.fromCodePoint(0xF2D0),
        "hyprland": String.fromCodePoint(0xF0108), // desktop icon
        "chevronDown": String.fromCodePoint(0xF078),
        "chevronUp": String.fromCodePoint(0xF077),
        "chevronRight": String.fromCodePoint(0xF0142),
        "check": String.fromCodePoint(0xF012C),
        "xmark": String.fromCodePoint(0xF00D),
        "arrowRight": String.fromCodePoint(0xF061),
        "key": String.fromCodePoint(0xF084)
    }
}
