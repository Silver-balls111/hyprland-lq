# Notifications & the OSD

Read this before touching `shell.qml`'s `NotificationServer`, `core/Notifs.qml`,
`bar/Toast.qml`, `bar/Osd.qml`, or the dashboard's notifications panel.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Quickshell owns notifications now — swaync is gone (2026-10-04)
- The `NotificationServer` in `shell.qml` claims `org.freedesktop.Notifications`.
  If swaync (or any other daemon) is running, only one of them wins the DBus
  name — kill swaync before testing (`killall swaync`; it was autostarted from
  `~/.config/hypr/config/autostart.lua`, which the user removes themselves).
- **If notifications ever disappear mysteriously, suspect name theft.** This
  happened once (2026-10-04): the user had a GNOME session open for reference,
  and its standalone notification daemon (a dbus-activatable `gjs` process
  running `/usr/share/gnome-shell/org.gnome.Shell.Notifications`) grabbed
  `org.freedesktop.Notifications` the moment it was free. Symptom: no toasts,
  and the qs log only says "Could not register notification server ... already
  registered". Diagnosis: `busctl --user list | grep Notifications` — see who
  owns the name (another session's daemon, swaync, dunst, mako, ...). Close
  the other daemon/session and quickshell re-registers automatically — no bar
  restart needed. A cheap guard is still in place:
  `~/.config/dbus-1/services/org.gnome.Shell.Notifications.service` with
  `Exec=/bin/false` shadows the dbus activation for this user (harmless
  outside GNOME sessions; delete if unwanted).
- **`n.tracked = true` in `onNotification` is not optional.** Without it the
  Notification wrapper is destroyed as soon as the handler returns, and any
  later `n.expire()`/`n.dismiss()` (toast timer, click-dismiss) throws
  `TypeError: ... is not a function` — the toast still *looks* fine, so only
  the qs log reveals it. History is safe regardless because `Notifs.push`
  snapshots plain JS data, never the QObject.
- **OSD (Osd.qml, 2026-10-04)** — volume/mic/brightness indicator, a port of
  end-4's ii `OsdValueIndicator`: service-driven, NOT notification-driven.
  Volume/mic via `Connections` on `Pipewire.defaultAudioSink/Source.audio`
  (`volumeChanged`/`mutedChanged`), brightness via a 400ms `Timer` polling a
  `FileView` on `/sys/class/backlight/<dev>/brightness` (kernfs emits no
  inotify events; device discovered once via `Process ls`; first successful
  read only calibrates `lastSeenBrightness` — it must not trigger). One
  visibility flag + "current indicator"; 1000ms hide timer restarted per
  trigger; `WlrLayer.Overlay` so it shows above the dashboard's Top-layer
  shield; `armed` flag ignores the Pipewire tracker's initial attach events.
  Sync-hint notifications (`x-canonical-private-synchronous`) are dropped
  entirely in `Notifs.push` — the OSD replaces them (a dbus-send test must
  send the hint as a proper typed dict entry; dbus-send's dict parsing mangles
  keys — use the python dbus module for tests). `Notifs.osdShowing` makes the
  toast shift down below the OSD.
  - Brightness poll is adaptive: 60ms for ~1.5s after any detected change
    (burst, feels instant during key holds), 400ms baseline.
  - Volume is hard-capped at 1.0: `onVolumeChanged` writes the sink back down
    if anything sets it higher; `StatusPill` scroll also caps at 1.0.
  - OSD volume icon thresholds mirror StatusPill exactly (`muted` /
    `< 0.5 → volumeLow` / else `volumeHigh`) — keep them in sync.
- **`Notifs.push` must record history/unread BEFORE the DND / dashboard-open
  early return** — that return only suppresses the toast. Recording after it
  (a real bug for a day) made every DND'd notification vanish: the unread
  counter ticked and the bell changed, but the panel stayed empty forever.
- The server lives at shell root, not inside `Variants`: one DBus owner, and
  one `Toast`, regardless of screen count.
- `Notifs.push` drops the toast (expires immediately) when DND is on or the
  dashboard is open — the entry still lands in history (unread counts up).
  Opening the dashboard calls `Notifs.markRead()`.
- The clock pill's bell is stateful (waybar notification-module glyph set):
  none F009C / unread F116B / dnd+unread F00A0 / dnd+quiet F0A93.
- Note: `notify-send` works fine in the user's own session (verified by the
  user; their volume/brightness keybind scripts reach the bar end-to-end). An
  earlier "undefined symbol notify_notification_get_activation_app_launch_context"
  failure happened ONLY inside the agent's exec shell — its library environment
  differs from the user's session, so don't conclude "tool X is broken
  system-wide" from agent-shell failures. To send test notifications from the
  agent shell, use `dbus-send` against org.freedesktop.Notifications instead
  (or the python dbus module, which is installed).
- **`hyprctl reload` re-runs `autostart.lua`** — every `hl.exec_cmd` fires
  again. While swaync is still in that file, a mere config reload respawns it
  and it steals `org.freedesktop.Notifications` back; kill it and quickshell
  re-registers on its own.
