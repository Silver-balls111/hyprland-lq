# Palette, icons & fonts

Read this before editing `core/Theme.qml`, `core/Colors.qml`,
`core/Icons.qml`, `ui/NIcon.qml`, or any matugen configuration.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Palette is Colors.md3 (matugen quickshell.json flow) + fonts are uniform (2026-10-07)
- Flow: matugen `[templates.quickshell]` (~/.config/matugen/config.toml)
  renders `~/.config/matugen/templates/quickshell.json` →
  `~/.local/state/quickshell/generated/colors.json` (md3 = 50 roles,
  palette = 108 tonal keys, base16 = 16). `core/Colors.qml` — the InioX
  matugen-themes quickshell pattern: `Singleton` + `FileView` + `JsonAdapter`
  (watchChanges → live reload) — exposes `Colors.md3/.palette/.base16`.
  `core/Theme.qml` maps md3 roles onto the UI palette; every color binding in
  the tree follows. The old colors.css → `applyPaletteCss` flow is REMOVED
  (shell.qml's FileView and Theme's function are gone; colors.css is deleted
  from the repo).
- Role mapping (Theme.qml top): `secondary` → pillBg/popupBg (translucent),
  `secondary_fixed` → pillHover/accent/accentSoft, `on_secondary` → fg,
  `error` → urgent, `error_container` → danger (dark tone, readable on light
  pills). Derived tones (fgMuted, track, divider, border, rowHover, inputBg)
  stay formulaic on top — don't give them matugen roles. Change the mapping by
  editing those bindings, not the consumers.
- **Until matugen's first run the md3 strings are `"transparent"`** — Theme
  falls back to a snapshot hex per role (secondary #c1c6dd, secondary_fixed
  #dde2f9, on_secondary #2a3042, error #ffb4ab, error_container #93000a) so
  the shell renders normally. `"transparent"` is also what an unloadable
  colors.json yields — same fallback covers it.
- **FileView traps still apply to Colors.qml**: its `onFileChanged: reload()`
  is REQUIRED (watchChanges alone only fires the signal); a JsonAdapter
  string property is compared as a plain string (`!== "transparent"`) and
  auto-converts when assigned to a `color` property; never declare two
  handlers for the same signal (QML: "Property value set multiple times" →
  whole config fails while the old engine runs).
- matugen notes: `[config.wallpaper]` must keep `set = false` with its
  `command`/`arguments` fields present (4.2 aborts on "missing field"
  otherwise). The kitty template block is ACTIVE again (post_hook =
  `kitty +kitten themes --reload-in=all Matugen` — no more kill-SIGUSR1
  noise). The user is developing zen-browser templates: matugen can die with
  "Failed to get the input and output paths from hashmap" from THOSE —
  unrelated to quickshell (its template is #2 and regenerates before any zen
  failure; verified per-template).
- All non-icon text: `Theme.textSize` (14.5) in Rubik, **no font.weight
  anywhere** (single rule, mirrors the waybar CSS). Only NIcon sizes differ.
  Icon glyphs remain the nerd font via `Theme.nerdFont`.

### Icons are Nerd Font glyphs, not fonts-of-opportunity
All codepoints in `Icons.qml` were taken verbatim from the user's waybar config
(battery level/charging arrays, volume low/high/muted, mic, wifi, bluetooth,
bell quartet). Power intentionally uses the md power glyph (font-metric
alignment), not the ⏻ text char. The bell set (`bell`/`bellRing`/`bellDnd`/
`bellSleep`) comes from the `custom/notification` module's format-icons:
none F009C / unread F116B / dnd+unread F00A0 / dnd+quiet F0A93. Media transport
glyphs are NOT in the waybar config: play f04b, pause f04c, prev f049 (◀◀),
next f04e (▶▶), music f001, xmark f00d.
`Icons.yOffset(name)` holds pixel corrections measured by rendering glyphs
against JetBrains Mono text — update it if you add glyphs. BT device rows all
use the plain bluetooth glyph (matches waybar).

Wifi strength uses the MDI graded set (render-tested, not just cmap-checked):
`f091f`/`f0922`/`f0925`/`f0928` = strength 1–4, `f092f` = outline (radio on,
not connected); `f05aa` stays the disabled/off glyph. `Icons.wifiGlyph(0..1)`
is reached through `glyph("wifiStrength", level)`; the bar's `NIcon` passes
`StatusPill.wifiSignal` (raw 0..1 fraction, -1 when disconnected).

**Font coverage lies: a codepoint in the cmap can still render wrong.** `next`
was initially f04d (fa-step-forward) — fc-query lists it as covered, but in
JetBrains Mono Nerd Font Propo it renders as a **filled square** (codepoint
collision). Always render-test new glyphs with a throwaway qs instance +
`grim` before committing them; don't trust fc-query alone.
