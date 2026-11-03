# Workspaces pill & the stale-cache trap

Read this before touching `bar/Workspaces.qml` — and check it first when
the shell maps its window but paints nothing.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Workspaces pill: fixed cell widths and the silent Repeater-id trap
State of `Workspaces.qml` after the 2026-10-04 debug session (uncommitted at
the time of writing — the user reviews commits themselves).

- **A Repeater `id` is NOT resolvable inside delegates created through
  `Pill`'s default-alias Row** (`content: contentRow.data`).
  `isLast: index === wsRepeater.count - 1` compiled, loaded, and *silently*
  threw `ReferenceError: wsRepeater is not defined` on every evaluation — the
  property just reads `false` forever, so the last workspace's edge highlight
  never appeared while the first one worked (`isFirst: index === 0` doesn't
  reference the Repeater). Only trace: a WARN line in qs logs. Fix in place:
  the model array is hoisted to `readonly property var wsValues` on the pill
  root and edge-ness is derived from data (`isFirst: modelData.id ===
  root.wsValues[0].id`, `isLast: … === root.wsValues[root.wsValues.length-1].id`).
  `root` DOES resolve inside those delegates. Any future per-delegate
  "am I first/last" logic must follow this pattern, never `Repeater.count`.
- **Edge caps REMOVED (2026-10-06, user request):** the first/last delegates
  used to draw 32×32 "cap" circles so the active fill reached the pill's
  rounded ends; the user wanted first/last to fill exactly like intermediate
  cells, so the caps and their `isFirst`/`isLast` plumbing are gone. Every
  cell now sits inside the Pill's `hpadding` and fills number-sized. (If ever
  re-added: the cells CANNOT resolve a Repeater `id` — derive edge-ness from
  `root.wsValues`, see the trap above.)
- **Width contract (FINAL 2026-10-07 — the wider-active design was tried,
  reverted, re-requested, and reverted again; do NOT re-introduce it):** every
  cell is ONE fixed width, `max(34, label + 26)`, and there is no
  `Behavior on width`. Switching workspaces animates COLOR only; the pill's
  width changes exclusively when the workspace count changes (a 6th+ slot
  appearing/departing). History: waybar-parity wider-active
  (`max(44, label + 36)` + 170ms OutCubic) shipped twice — the net-zero width
  swap keeps the pill's TOTAL constant for equal-length labels, but the
  growing/shrinking fill mid-switch reads as "the pill resizing" and the user
  ultimately chose fully static geometry. Hover/idle/active widths are
  identical by design; nothing about a workspace switch moves any geometry.
- **Debug notes from that session:** `console.log` never surfaces through `qs`
  — use `console.warn`. Verify renders by pixel-scanning screenshots
  (contiguous color runs per row; accent `#f7c2d1` vs pale `pillBg` are
  near-identical at thumbnail size and eyeballing lies). The item tree can say
  "flush" while pixels say "gap" and both be right — geometry is one suspect,
  rendering is another.

### Stale Quickshell cache = invisible bar
After QML edits, a shell can map its window but paint *nothing* (wallpaper
shows through, `hyprctl layers` still lists the surface, **zero** errors in
any log). Cause: corrupt `~/.cache/quickshell` and/or
`/run/user/1000/quickshell/vfs` entries. `rm -rf` both and relaunch — cost
most of a session before being identified. 2026-10-05 addendum: it can hit a
SINGLE window after a rework (the toast stack mapped with correct geometry
and painted nothing while the rest of the shell rendered fine) — same fix.
Also: notification wrappers can die out-of-band even when `tracked` was set
(server-side lifecycle) — guard every `notif.expire()/dismiss()` call with
try/catch or the toast ticker throws "Type error is not a function".
