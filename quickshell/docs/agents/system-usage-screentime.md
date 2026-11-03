# System usage & screen time

Read this before touching `popups/SystemUsage.qml`, `core/ScreenTime.qml`,
or the dashboard's calendar column.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### System usage section (SystemUsage.qml + ScreenTime.qml, 2026-10-05)

Bottom of the dashboard's calendar column, below the calendar. Layout per
user round 2: **no card background** — the profile rows and the CPU / Memory /
Disk bars blend directly into the popup (they looked "packed together" with a
bg). The section is anchored below the calendar's **worst-case (6-row)
footprint** (`CalendarPanel.maxContentHeight`) and stretched to the column
bottom, so it never moves while browsing 4/5/6-row months and never
overflows; leftover height is distributed evenly between the profile block
and the bar rows (`gap = (height − 66 − 3×28) / 3`, min 10).

- **Profile rows are fastfetch-style** (user's reference screenshot): a
  circular avatar (`assets/pfp.png`, Canvas-masked) + three value-only rows —
  distro, screen time, `up X hours, Y minutes`. The user explicitly dropped
  the "Hyprland" row ("no need for generic hyprland in there, screen time is
  fine") and asked for the verbose uptime format. Screen time stays compact
  (`2h 14m`) to parallel the reference's short middle row.
- **Rice portability**: the avatar is repo-relative
  (`Qt.resolvedUrl("assets/pfp.png")` — anchors to the QML file's own dir, no
  `~/Pictures` dependency; replace the file to change it — placeholder is a
  magick-generated silhouette). The lock screen's `profilePhotoPath` points
  at the SAME asset (the old `~/Pictures/wallpapers/final_logo.png` never
  existed and is gone for good). The distro row is parsed from `/etc/os-release` (PRETTY_NAME,
  fallback NAME, fallback "Linux") — never hardcode "Arch Linux".
- **Quickshell 0.3.1 has NO CPU/RAM/temp/disk API.** `/usr/lib/qt6/qml/Quickshell/Services/`
  has no System module and no `CpuUsage`/`Memory` types exist in any qmltypes
  (those landed in later Quickshell). Everything is polled like the OSD's
  backlight: `FileView` + Timer-driven `reload()` + parse in `onLoaded`
  (procfs/sysfs emit no inotify events — `watchChanges` is useless there).
- **Data sources**: CPU = `/proc/stat` aggregate line, usage = 1 − Δidle/Δtotal
  over the 2s poll (idle = field 4 + iowait field 5, total = first 8 fields;
  first read after open only calibrates — the OSD `armed` pattern); RAM =
  `/proc/meminfo` `MemTotal − MemAvailable` ("available", not "free", is what
  free(1)/htop count; fields are "kB" but really KiB); CPU temp = hwmon probe
  picks `k10temp|coretemp|zenpower` `temp1_input` (this box: hwmon5 k10temp),
  fallback `/sys/class/thermal/thermal_zone0/temp` (acpitz, millidegrees);
  disk = `df -B1 --output=used,size --total -x tmpfs -x devtmpfs -x efivarfs`
  once per open, parse the TOTAL row (single drive: / + /boot + /home sum);
  uptime = `/proc/uptime` first float → bootEpoch once per open, formatted per
  tick. SystemUsage polls ONLY while the dashboard is open (start/stop from
  DashPopup's `onVisibleChanged`).
- **MultiEffect maskSource is BROKEN in layer-shell windows** — the big one
  from this round. `MultiEffect { maskEnabled: true; maskSource: someItem }`
  renders NOTHING (mask-off renders fine) in the dashboard popup AND probe
  windows, with the mask item BOTH offscreen (the lock screen's x:-3000
  pattern) AND on-screen. Probes: plain Image ✓, MultiEffect without mask ✓,
  with mask ✗ — the mask texture simply never samples. The lock screen never
  caught it because its two RoundedImage usages never had a loadable image
  (photo path 404, media card commented out). `RoundedImage.qml` is therefore
  a **Canvas-drawn clip** now: hidden Image feeds `imgStatus` + natural size
  via the `sourceSize` READ-BACK (works — verified 256x256), Canvas draws the
  rounded-rect path (`arcTo`) + cover-crop `drawImage` with the URL registered
  through `canvas.loadImage()` (repeat per source change + on paint). Canvas
  is software-rasterized — works in every window type, inside `clip: true`,
  everywhere. Don't go back to maskSource for anything in this repo.
- **ScreenTime** (`IdleMonitor` from `import Quickshell.Wayland`, timeout in
  SECONDS — property is `double` s, not ms): mirrors the user's hypridle
  chain (backlight dim 300s < dpms-off 330s < lock 420s < suspend 600s), so
  isIdle tracks real screen-off almost exactly and suspend counts as off.
  On isIdle flips: bank the open stretch / reopen it, then persist. 5-min
  checkpoint Timer covers crash-survival and the midnight rollover (lazy
  check in every read/write: dayKey ≠ today → reset). An awake stretch
  spanning midnight counts entirely into the new day (accepted). The sidecar
  read/write uses a Process (`cat` / `printf > file`) — same reasoning as the
  pin sidecars (missing-file is normal first-run state; FileView callback
  timing burned us before).
- **Singleton laziness gotcha**: a pragma-Singleton component does NOTHING
  until first accessed. ScreenTime must accumulate all day even if the
  dashboard is never opened, so shell.qml calls `ScreenTime.init()` in a
  `Component.onCompleted` on ShellRoot (attached handlers work on ShellRoot;
  verified). Without that line the accumulator simply never exists.
- **QtObject roots still can't host children** (hit again while writing
  ScreenTime as a QtObject singleton: Timer/Process/IdleMonitor children →
  "Cannot assign to non-existent default property"). Root is an `Item`.
- **`Process.exec()` exists but the repo convention is `command` + `running
  = true`** — keep new code on `running = true` (ScreenTime/SystemUsage
  originally used `.exec()`, converted).
- **Glyphs** (clock F0150, monitor F0379, cpu F061A, memory F035B, disk
  F02CA, arch F303, linux F033D): picked by reading the font's own glyph
  table with fontTools (`TTFont.getBestCmap()` reverse name→codepoint on
  `/usr/share/fonts/TTF/JetBrainsMonoNerdFontPropo-Regular.ttf`), then
  render-tested via a throwaway strip window. The distro glyph maps
  os-release's name → `arch`, else the penguin `linux`. md-cpu_64_bit was
  rejected (embedded "64" text unreadable at 15px).
- **Two live-bar traps while verifying**: (1) an intermediate reload between
  two edits of the SAME feature logs errors forever after (e.g.
  `ReferenceError: dateHeader is not defined` from a binding whose target id
  landed in the next save) — count occurrences before/after a forced reload
  before treating it as real; the final files were clean. (2) When the bar
  process is dead, its log keeps existing and greps "succeed" — check
  `pgrep -x qs` / `hyprctl layers` FIRST (see below).
- **Red herring to remember**: while verifying, the "live" bar instance
  turned out to be DEAD (no qs process at all, no quickshell layers in
  `hyprctl layers`) — its log had frozen mid-session, and grepping it for
  evidence of the singleton led to a long false "ScreenTime doesn't
  materialize" chase. `pgrep -x qs` / `ps -eo comm | grep qs` FIRST, and
  `hyprctl layers`, before debugging a "stale" instance. The instance had
  also stopped hot-reloading before it died (log frozen despite saves) —
  a fresh `qs -c rice` picked everything up instantly (also cleared
  `/run/user/1000/quickshell/vfs/*` first per
  [workspaces-stale-cache.md](workspaces-stale-cache.md)).
