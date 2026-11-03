# Lock screen

Read this before touching `standalone/Lockscreen.qml`, `core/LockState.qml`,
or the greeter's shared patterns.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Lock screen (Lockscreen.qml, 2026-10-05)


Hyprlock replacement. Runs INSIDE the main shell instance (user decision —
not a standalone `qs -p` config "for now"): a `WlSessionLock` sits unlocked
until something engages it; on success `LockState.engaged` drops and the
bar keeps running. Styling per user feedback (round 3): NOTHING sits on a
card/chip and NO text has any shadow/glow — every text is plain palette
text over the blur (the soft white MultiEffect glow was tried and
explicitly rejected as a "weird effect"); legibility is the wallpaper's
problem. The battery chip was rejected too (kept as a comment in the right
column). Password dots are 5px; fail feedback is a thin gradient border
(Canvas — Rectangle borders can't take gradients) in hyprlock's exact
fail_color (#ff6633→#ff0066, 40deg, alpha .93) that shows ONCE and fades
out over 1.8s — NO ring while verifying and NO looping animation. The fail
message lives INSIDE the field (fail_text parity): the buffer is cleared on
failure so it replaces the dots, and it hides as soon as the user types
again (effBuffer gate). The displayed failure text is ALWAYS
"Authentication failed" — pam.message goes to console.warn only (their PAM
stack's message is literally "wrong password"; the user caught the ternary
preferring it). Readability is solved by SAMPLING: a 16x9 offscreen
Canvas (`lumSampler`, loadImage + getImageData) averages the wallpaper's
luminance and flips `root.wallDark`, which drives `lockFg`/`lockFgMuted` —
light text on dark wallpapers, dark palette fg on light ones (whole-image
average — a wallpaper split bright-top/dark-bottom classifies by its mean;
threshold is the `128` in lumSampler). Lock/unlock fades are QML-side
(`lockFadeInMs`/`lockFadeOutMs`, both 500ms Linear): hyprlock's
`animation = fadeIn, 1, 5, linear` speed param is DECISECONDS — hyprutils
`getPercent()` computes `duration = 100 × speed` ms, so 5 = 0.5s, NOT 5s
(the "5s" reading cost the user a "way too slow" round; they verified by
setting the knob). The unlock fade MUST run in QML before
`LockState.engaged` drops, since a layer surface that is already destroyed
cannot be animated by compositor layer rules; keys are ignored while
`unlocking`). The fades target a `uiFade` wrapper around the UI overlays
ONLY — the wallpaper stays opaque so the surface's black backing never
shows mid-fade (fading the whole content produced a black flash). Round 8
attempted the "true" hyprlock cross-fade (transparent
`WlSessionLockSurface.color` + wallpaper inside uiFade) — it looked perfect
in preview but the user REJECTED it: on a real lock the black flash returns
on enter AND exit. Hyprlock can cross-fade because it fully controls its
own render pipeline; a Quickshell lock surface cannot replicate it. DO NOT
retry — the split fade (opaque backing, overlays-only fade) is final.
Weather, status and the keyboard-layout switcher are commented out (user
request, round 6) — their Processes at the root are commented with them;
battery stays. TWO
lifecycle traps cost a debug round (user caught it: preview worked, real
lock stayed palette-dark): (1) in the real bar the content is created with
`wallpaperPath` ALREADY set, so an `onWallUrlChanged`-only trigger never
fires — the load must also start from `Component.onCompleted`; (2) a
Canvas is NOT `available` during construction, so `getContext()` returns
null ("Unable to use getContext() at this time") — the decode must wait
for the `available` handshake and be retried (`decodePending` +
`onAvailableChanged`). Caps state: single-flight `hyprctl -j devices`
probe (1s timer guarded on `Process.running`, plus an immediate re-probe
on the CapsLock keypress in `handleKey`); the capsLock field is only
assigned when present.
- **Round-7 fixes (2026-10-06, dir-cleanup fallout)**: (1) the wallpaper
  background Image had been rebound to `Qt.resolvedUrl("../assets/pfp.png")`
  (a copy of the avatar's expression) with the real
  `"file://" + wallpaperPath` commented above it — pfp-as-wallpaper; the
  awww query + parse were never the problem, don't "fix" them. (2) The
  sampler's failure modes were ONE-DIRECTIONAL: a sample taken before the
  decode finished (or a failed load) reads all-transparent pixels whose
  0-luminance classifies the wallpaper dark forever — `sample()` now counts
  alpha≠0 coverage, retries via a 250ms Timer (5 cap, `loadImage` re-issued
  on the `available` handshake), and falls back to `wallDark = true` when
  exhausted (unloadable wallpaper = black backing = light text is right).
  (3) Classification uses Rec.709 LUMA — a blue-saturated wallpaper can
  show a bright channel-mean (~167) while its luma is ~105 → "dark" with
  light text is CORRECT for it; check with
  `magick <img> -resize 16x9! -format "%[fx:0.2126*r+0.7152*g+0.0722*b]"`,
  not `%[fx:mean]`. The photo ring (border #1b1d1f) is gone entirely.

- **0.3.1 API names**: `WlSessionLock` / `WlSessionLockSurface` in
  `Quickshell.Wayland` (NOT `SessionLock*` — those are newer). The surface
  component auto-instantiates per screen; there is NO `unlockRequested`
  signal — unlock = `locked: false`. Killing quickshell while locked bricks
  the session (protocol keeps it locked, solid color) → recovery: TTY +
  `loginctl unlock-session`.
- **`GlobalShortcut` resolves only via `import Quickshell.Hyprland`** (the
  shortcuts live in an internal module that module re-exports) — `import
  Quickshell` alone gives "GlobalShortcut is not a type" even though
  shell.qml happens to also import Hyprland.
- **A `QtObject` root cannot host children** ("Cannot assign to
  non-existent default property") — Lockscreen's root is an invisible
  `Item`. Also: `id:` values cannot contain dots.
- **Trigger wiring**: `qs:lock` GlobalShortcut (appid `qs` — standalone
  desktop tool, NOT `qs-bar`; renamed in round 8 when the lockscreen became
  standalone). From SCRIPTS (hypridle lock_cmd) the ONLY working form is the
  **dispatch request with the descriptor**:
  `hyprctl dispatch 'hl.dsp.global("qs:lock")'`. TRAPS (both cost rounds):
  plain `hyprctl dispatch global ...` / `dispatch eval` die in the Lua
  parser, and `hyprctl eval 'hl.dsp.global(...)'` returns "ok" but is a
  NO-OP — eval discards the descriptor, so the shortcut never fires (the
  user's hypridle silently failed to lock on exactly this; verified by
  popping the dashboard: eval 0 layers, dispatch 1 layer). PowerPopup
  Lock sets `LockState.engaged = true` (its `run()` takes the model entry;
  entries carry either `cmd` or `act: "lock"`).
- **NEVER guard engage() on `LockState.engaged`** (round-8 lockout, user
  caught it: the PowerPopup path set the flag first, so engage() — invoked
  BY the flag change — returned immediately: lock surfaces with stale state
  and a PAM that never started = complete lockout, no input accepted). The
  guard is the lockscreen's own `sessionActive` flag; `LockState.engaged` is
  only an external trigger mirror, and `WlSessionLock.locked` binds to
  `sessionActive && !testMode`.
- **PAM**: `PamContext` (`Quickshell.Services.Pam`) with `config: "login"` —
  literally the stack hyprlock gets (`/etc/pam.d/hyprlock` is just `auth
  include login`), so NO custom PAM file is needed (sudo unavailable in the
  agent shell; `pamConfig` property can point at a custom file later).
  Verified: `start()` → `pamMessage` "Password:" with `responseRequired:
  true`. Gotchas: `pamMessage` has NO parameters (read `message`/
  `responseRequired` off the object); `completed(result)` carries a
  `PamResult` enum (Success/Failed/Error/MaxTries) — restart `start()` after
  Failed/MaxTries, DON'T restart on Error (the `error` signal handles it);
  Enter before the prompt arrives sets `pendingSubmit`, answered on the
  first `pamMessage`. On engage, `pam.start()` failing locks anyway with an
  on-screen "PAM unavailable" message (privacy over availability).
- **MultiEffect semantics (cost a debug round, still true even though the
  text-glow was removed)**: MultiEffect does NOT hide its source — you
  must set `visible: false` yourself, and an INVISIBLE source still renders
  through the effect. `opacity: 0` on the source is the documented variant
  that KEEPS touch/click input. Anchoring the effect to the source with
  default autoPadding produced offset ghost-doubles; manual geometry +
  `autoPaddingEnabled: false` + `paddingRect` is deterministic. This now
  only matters for the wallpaper blur and the RoundedImage mask
  (photo/album art). Qt docs:
  doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html.
- **Time is 12h via manual math** (`timeText` property): Qt's `hh` is only
  12-hour when `AP` is in the SAME format string, and the AM/PM is a
  separate smaller Text here.
- **hypridle-data polls**: one 250ms `hyprctl -j devices` Process (conf's
  `cmd[update:250]` parity) feeds BOTH `capsLock` and `active_keymap` of the
  main keyboard (fields verified via jq). `hyprctl switchxkblayout all
  next` is a top-level hyprctl command — not a dispatch — so it works from
  QML despite the Lua IPC change.
- **weather.sh quirk**: the user's script prints ONLY on a cache hit; a
  fresh fetch writes `/tmp/cache/wttr_cache.txt` and prints nothing. The
  wrapper runs it then cats the cache (`sh -c 'bash "$1" >/dev/null; cat
  /tmp/cache/wttr_cache.txt'`). Started at `Component.onCompleted` AND on
  engage — the 60s timer alone missed the first minute.
- **Commented-hyprlock-feature blocks** (user verifies, then comments out
  themselves): profile photo (130px circular, `profilePhotoPath` → the repo
  asset `assets/pfp.png`; COMMENTED OUT in round 8 at the user's request,
  nudged 30px toward the password field for when it returns), weather, status
  line (invented content: vol/mic/bt — original status.sh never existed; both
  it and weather are commented out already), keyboard-layout
  switcher (commented out too), MPRIS media card (art via `trackArtUrl`,
  only while PLAYING — widget-box-color.sh parity). The battery chip was
  REJECTED in round 3 —
  it survives only as a comment in the right column. hyprlock toggles are
  properties: `hideInput`, `asteriskDots`. Design reference the user pointed
  at: end-4/dots-hyprland `ii` quickshell module (lock/polkit folders) —
  their Lock visuals live in `common/panels/lock`, `PasswordChars.qml` shows
  their per-char Material shapes.
- **Preview/testing (NEVER real-lock from the agent)**: `/tmp/locktest.qml`
  (keep out of the repo) imports the repo via `file:` URLs to `core/` + `standalone/`, applies
  colors.css to Theme, and instantiates `Lockscreen { testMode: true }` —
  the same content renders in an Overlay `PanelWindow`
  (`quickshell:lockscreen-test`), Enter SIMULATES a wrong password (no PAM),
  Esc closes when the buffer is empty. `testPreview`/`testState`/`testCaps`
  render state variants; `LOCK_FAKE_MEDIA=1` forces the media card. Screenshot
  ≥5s after launch (UPower populates ~3s — earlier shots showed no battery).
  Round-1 black screenshots were a red herring: `hyprctl layers` + magick
  pixel-scans showed the window mapped and painting; trust those over a
  single Read of a PNG.
