pragma Singleton
import QtQml

// Nerd Font glyph map. Volume/mic/wifi/bluetooth/battery/clock/bell/power glyphs
// are taken verbatim from the user's waybar config.jsonc; the rest are matching
// nerd glyphs.
QtObject {
    function glyph(name, level) {
        if (name === "battery") return batteryGlyph(level, false);
        if (name === "batteryCharging") return batteryGlyph(level, true);
        return glyphs[name] || "";
    }

    // per-glyph vertical correction (px) — nerd font ranges have differing
    // metrics; values measured by rendering glyphs and comparing ink centers
    // against the JetBrains Mono text center
    function yOffset(name) {
        return yOffsets[name] || 0;
    }

    readonly property var yOffsets: {
        "bell": 0.5,
        "wifiOff": 0.5,
        "bluetooth": 0.5,
        "power": -1
    }

    // level: 0..1; mirrors waybar's battery format-icons from config.jsonc
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
        "volumeLow": String.fromCodePoint(0xF027),
        "volumeHigh": String.fromCodePoint(0xF028),
        "volumeMuted": String.fromCodePoint(0xF0581),
        "mic": String.fromCodePoint(0xF036C),
        "micOff": String.fromCodePoint(0xF036D),
        "wifi": String.fromCodePoint(0xF1EB),
        "wifiOff": String.fromCodePoint(0xF05AA),
        "bluetooth": String.fromCodePoint(0xF294),
        "bluetoothOff": String.fromCodePoint(0xF00B2),
        "clock": String.fromCodePoint(0xF43A),
        "bell": String.fromCodePoint(0xF009C),
        "power": String.fromCodePoint(0xF0425),
        "chevronLeft": String.fromCodePoint(0xF0141),
        "chevronRight": String.fromCodePoint(0xF0142),
        "check": String.fromCodePoint(0xF012C),
        "lock": String.fromCodePoint(0xF033E)
    }
}
