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
        "bellRing": 0.5,
        "bellDnd": 0.5,
        "bellSleep": 0.5,
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
        "bell": String.fromCodePoint(0xF009C),
        "bellRing": String.fromCodePoint(0xF116B),
        "bellDnd": String.fromCodePoint(0xF00A0),
        "bellSleep": String.fromCodePoint(0xF0A93),
        "power": String.fromCodePoint(0xF0425),
        "chevronLeft": String.fromCodePoint(0xF0141),
        "chevronRight": String.fromCodePoint(0xF0142),
        "xmark": String.fromCodePoint(0xF00D),
        "check": String.fromCodePoint(0xF012C),
        "lock": String.fromCodePoint(0xF033E),
        "logout": String.fromCodePoint(0xF05FD),
        "restart": String.fromCodePoint(0xF0709),
        "suspend": String.fromCodePoint(0xF04B2),
        "hibernate": String.fromCodePoint(0xE7FC),
        "music": String.fromCodePoint(0xF001),
        "brightness": String.fromCodePoint(0xF185),
        "play": String.fromCodePoint(0xF04B),
        "pause": String.fromCodePoint(0xF04C),
        // f04d renders as a filled SQUARE in this font (codepoint collision) —
        // "forward" f04e is the ▶▶ pair-mate of "prev" f049's ◀◀
        "prev": String.fromCodePoint(0xF049),
        "next": String.fromCodePoint(0xF04E),
        // clipboard panel — md arrow expand/collapse (user-picked glyphs)
        "search": String.fromCodePoint(0xF002),
        "expand": String.fromCodePoint(0xF0616),
        "shrink": String.fromCodePoint(0xF0615),
        "star": String.fromCodePoint(0xF006),
        "starFill": String.fromCodePoint(0xF005),
        "clipboard": String.fromCodePoint(0xF0EA),
        // system usage panel (dashboard) — md-* glyphs, names read from the
        // font's own glyph table and render-tested (cmap presence can lie)
        "clock": String.fromCodePoint(0xF0150),
        "monitor": String.fromCodePoint(0xF0379),
        "cpu": String.fromCodePoint(0xF061A),
        "memory": String.fromCodePoint(0xF035B),
        "disk": String.fromCodePoint(0xF02CA),
        // distro row of the dashboard profile card (matched against
        // /etc/os-release's NAME, "linux" is the fallback)
        "arch": String.fromCodePoint(0xF303),
        "linux": String.fromCodePoint(0xF033D)
    }
}
