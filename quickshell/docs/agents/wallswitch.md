# Wallpaper switcher

Read this before touching `standalone/Wallswitch.qml`, `core/Actions.qml`,
or the matugen wallpaper flow.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Wallpaper switcher (Wallswitch.qml, 2026-10-04)

skwd-wall's "Slices" picker, ported to QML minus the feature buffet. Replaces
the rofi `~/.config/rofi/wallpaper-switcher/wall-switcher.sh` flow entirely
(the script, its `.rasi` theme and the `wall_switch` variable in
`variables.lua` are dead weight now — the picker shells out to the binaries
directly).

- **Trigger**: `GlobalShortcut` appid `qs`, name `wallpaper-switcher` →
  `Popups.toggle("wall")` (its OWN appid, not `qs-bar` — the user wanted the
  picker identifiable as a desktop tool rather than a bar feature). User
  binds e.g.
  `hl.bind(mainMod .. " + W", hl.dsp.global("qs:wallpaper-switcher"))`. The
  window is instantiated at shell root via a lazy Loader (created on open,
  destroyed on close) declared AFTER `Variants` — the
  fullscreen shield is INVISIBLE (no dim; user rejected the dark backdrop:
  skwd floats over the live desktop) and must stack above the bar so a bar
  click closes the picker first, matching the other popups' convention.
- **Apply = two binaries, exact known-good args**, executed by
  `Actions.applyWallpaper(path, trans)` (core/Actions.qml — the runner MUST
  live at singleton scope, see the lazy-popups Process rule): awww
  + matugen as one `sh -c` with the path/transition passed as positional
  argv (filename-proof):
  `awww img "$1" --transition-type "$2" --transition-duration 1.2
  --transition-fps 60 && matugen image "$1" --prefer darkness --config …`.
  `$2` is a random of fade/wipe/outer/grow/random. NB: the old rofi script's
  fifth entry `slide` is NOT a valid awww 0.12.1 transition — every apply
  that rolled it failed with "invalid value 'slide'" and (via the `&&`)
  silently skipped matugen too. Keep transition values inside awww's set.
  **matugen's `config.toml` must keep `[config.wallpaper] set = false`** —
  user-verified: with `false` matugen only regenerates templates (incl. the
  `hyprctl reload` post-hook), with `true` it re-applies the wallpaper with
  its own `center` transition and would double-apply. There is NO CLI flag
  to override it (checked 4.2.0 `util/arguments.rs`). awww's non-zero exit
  short-circuits matugen so the palette can never desync from the wallpaper.
- **Data**: `find ~/Pictures/wallpapers -type f` (same ext glob as the old
  script; RECURSIVE since 2026-10-07 — wallpapers may sit in subdirectories
  of `wallDir` like `images/`, and the ext glob keeps non-image files such
  as `scripts/` out) piped to `sort`, plus
  `awww query` parsed with `(?<=image: ).*` (same as hyprlock-auto.sh). Both
  re-run on every open; selection resolves when the list lands (the query may
  arrive before or after it — `resolveSelection()` handles both orders).
- **Carousel mechanics**: 11 recycled slots each hold a stable `wallIdx`;
  `layoutSlots()` (on every `centerPos` change) keeps the indices around
  `floor(centerPos)` assigned, reassigning only far-edge slots whose opacity
  is ~0. Slot geometry is a pure function of the wrap-around distance
  `d = wallIdx - centerPos` (`signedDist`): width/shear/dim lerp toward the
  strip shape, the first strip hugs the center image's edge (`slotOffset()`),
  later ones step `stripW + gap`. **The center frame is FIXED `slotH * 16/9`**
  (user-requested: same box for every wallpaper, non-16:9 center-crops — do
  NOT bind the frame to the image's natural aspect, it rescales the whole
  row per wallpaper). **The shear is UNIFORM across all slots including the
  center** — user correction against the reference: skwd leans the whole
  plane at one angle; an earlier straighten-at-center morph was wrong. `centerPos` has a 260ms OutCubic Behavior **gated by
  `animateNav && everOpened`** — opens and Home/End must snap, or the first
  open flies across 471 entries (and `enabled` belongs on the `Behavior`,
  NOT on the `NumberAnimation` — "Cannot assign to non-existent property").
- **Geometry is derived, not fixed pixels** (user-tuned against the
  reference): `sideSlots = 4` strips per side, `margin = 5%` of screen width
  of empty desktop at the row ends, `pitch = (scrW/2 - margin - centerW/2) /
  sideSlots`, `stripW = pitch - gap` — so exactly 4 strips fit between the
  center frame and the margin on any screen width. `shearK = 0.15` (~8.5°;
  the first 0.35 was way too slanted per user). Slots beyond `|d| = 4` fade
  out by 4.5 and hide — maxSlots is 9 (the outermost pair are just invisible
  teleport targets for recycling). **The dim is NOT in QML**: the user wants
  the compositor to dim what's behind the picker via a `dimaround` layer
  rule on namespace `quickshell:wallswitch` (README setup step 4 has the
  snippet) — keep the QML shield invisible.
- **Filename chip only on the focused slot** (`visible: wallIdx ===
  selected`, not a distance gate) — side strips are unnamed like skwd; the
  selected-slot condition avoids the two-chips-at-midpoint flicker a
  `|d| < 0.5` gate would give mid-animation, and it's a pure visibility
  toggle (no image reloads involved).
- **Keys** (all user-confirmed working): Esc / arrows / `Tab`/`Backtab` /
  `Home`/`End` / Enter+Space on a focus-sink Item via `Keys.onPressed`, PLUS
  `Keys.onReturnPressed` and `Keys.onEnterPressed` — Enter did not apply
  until the specific handlers existed (Space worked all along from
  onPressed; root cause never explained). A 250ms `lastApply` guard in
  `apply()` makes a double delivery a no-op, and any unrecognized extended
  key (>= 0x01000000) `console.warn`s its code. The `dimaround` layer rule
  on `quickshell:wallswitch` is also user-confirmed.
- **Search (type-to-filter, implemented 2026-10-04):** printable keys append
  to `query` (Space still applies — only `event.text >= "!"` with no
  Ctrl/Alt/Meta counts as typing), Backspace pops, Esc clears the query
  first and closes only when it's empty. `onQueryChanged: rebuildShown()` is
  THE filter hook — without that one line, typing does nothing (it shipped
  missing once; the seed-before-load test passed because the list-load
  rebuild ran after the seed — always test the typing path with the query
  set AFTER the list is loaded). The carousel runs on `shown` — a
  filtered list of indices into `walls` (case-insensitive basename
  substring); `selected` stays a walls-index (apply/currentPath logic
  untouched) while `selectedPos` = its position within `shown` drives
  `centerPos`. Filter changes SNAP (`animateNav = false`), never slide.
  A chip above the row shows `query · N matches` only while a query is
  active; a distinct "No matches" chip covers the empty filtered set. With
  fewer matches than slots the same wallpapers repeat around the wrap —
  inherent, not a bug. Gotcha hit live: Quickshell flips `visible`
  ASYNCHRONOUSLY on the real map — a `query = ""` reset in
  `onVisibleChanged(visible=true)` ran AFTER the test seeded the query and
  clobbered it; the reset therefore lives on the CLOSE branch
  (`else if (query !== "") query = ""`).
- **Kitty stderr noise on apply, solved:** matugen's config had a stale
  `[templates.kitty]` block whose `post_hook = 'kill -SIGUSR1 $(pgrep
  kitty)'` ran on EVERY palette regen; with no kitty running `pgrep` returns
  nothing and `kill` prints its usage error, which matugen reports on stderr
  and the picker's apply-Process logs as "wallswitch: apply stderr". The
  block is commented out in `~/.config/matugen/config.toml` — if that
  warning ever returns, check for resurrected template blocks there. The
  picker deliberately logs matugen stderr (it surfaces real failures); don't
  silence it.
- **Jagged slanted edges — PARKED shader experiment, NOT in the live code.**
  Status: the user reverted the switcher to the `shearWrap` + `Matrix4x4` +
  `clip` version (edges aliased, accepted for now); `shaders/` is kept
  committed so a future session doesn't start from scratch. The conclusion
  stands: there is NO simple fix — a transformed quad's edges are rasterized
  WITHOUT anti-aliasing; `clip: true` is binary scissor/stencil;
  `layer.enabled/smooth/samples` only change texture *sampling* (the quad
  boundary stays hard — tried, did NOT fix it, don't claim otherwise);
  Quickshell 0.3.1 exposes no window-MSAA property (checked the qmltypes).
  The working-but-reverted approach: each slot = `ShaderEffect` with
  prebuilt `.qsb` shaders masking the parallelogram with a 1px `smoothstep`
  (AA verified numerically: pixel rows across the border show blended
  intermediate values). What killed it — TWO bugs shipped together in the
  rewrite and my verification only checked the border zoom, not the frame:
  1. **Mask clipped to a rectangle** (user's exact diagnosis): fragments
     outside a ShaderEffect's own rect never rasterize, and the parallelogram
     extends `k*slotH/2` px beyond it — the overhang must be added back by
     widening the effect item (negative left/right anchor margins) and
     masking at `x - pad + shear*(y - H/2)` with `pad = shearK*slotH/2`.
  2. **Lean flipped**: the old matrix's `m12 = -k` corresponds to a mask
     left edge of `pad - shear*(y - H/2)` (tops lean RIGHT); using
     `+shear*(y - H/2)` mirrors it.
  If resumed, start from `shaders/wallslot.{vert,frag}` (sources carry
  comments), recompile with
  `/usr/lib/qt6/bin/qsb --glsl "100es,440" --hlsl 50 --msl 12 -o X.qsb X`,
  and re-apply the geometry fix above BEFORE screenshotting. qsb gotchas
  (all hit live): Qt 6 ShaderEffect takes ONLY `.qsb` URLs — runtime GLSL
  strings are treated as file paths; `--glsl 100es` alone is NOT enough
  (desktop-GL tries versions 120..460 → "No GLSL shader code found"); the
  vertex shader must declare `qt_TexCoord0` (location 1) even when unused;
  uniform block = `qt_Matrix`, `qt_Opacity`, then QML custom properties in
  ALPHABETICAL order (std140, binding 0), sampler `layout(binding = 1)`.
- **Parallelogram slices: shear a clipped WINDOW, never the Image.** The
  sheared Image is ~`k*slotH` px wider than its strip; with no clip (or a
  plain `clip: true` on the slot) that content spills over the neighboring
  slots and hides their chips/strips (cost a debug round). Structure:
  outer slot → `shearWrap` Item with the `Matrix4x4` → inner window Item
  (`clip: true`) → Image + dim + border inside. The clip rect transforms
  WITH the wrapper, giving a clean leaning slice. `m12 = -k` puts the TOP
  edge to the right (right-leaning, what the user chose over skwd's
  left-lean); `m14 = k*slotH/2` pivots the shear on the vertical middle.
- **Decode cost**: `sourceSize.width` quantized to 128px steps (the slot
  width morphs continuously; an exact binding would re-decode every frame),
  `sourceSize.height: 0`, `asynchronous: true`, `cache: true`.
- **Debug pattern that paid off**: binding errors fail SILENTLY to a wrong
  value — renaming `W`/`H` (uppercase property names are illegal, an
  existing gotcha) left `slotH: Math.round(H * 0.58)` throwing
  `ReferenceError` on every eval and reading 0, with zero visual errors and
  everything else working. A temporary `console.warn` Timer dumping the slot
  tree (plus a `property alias imgItem: img` for statuses) found it in one
  run. `console.log` doesn't surface, `console.warn` does.

  run. `console.log` doesn't surface, `console.warn` does.
- **Test-instance trap**: a throwaway never runs shell.qml, so Theme keeps
  DEFAULTS — the accent border reads default pink #f7c2d1 in test
  screenshots and the matugen accent in the live bar. Don't scan for the
  wrong color when pixel-checking.
