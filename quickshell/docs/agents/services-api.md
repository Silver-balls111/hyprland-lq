# Services API & Hyprland IPC

Read this before wiring any Quickshell service (Pipewire, Networking,
UPower, SystemTray, Mpris, …) or dispatching Hyprland commands.

Part of [AGENTS.md](../../AGENTS.md) — the hub file links here.

### Hyprland ≥ 0.56 IPC is Lua
The old `dispatch workspace N` syntax is a Lua parse error now (even
`hyprctl dispatch` fails). Working form: `hl.dsp.focus({ workspace = N })`.
`Workspaces.qml` probes `hyprctl version` at startup and falls back to the old
syntax on Hyprland < 0.56. Enumerating Lua APIs: the socket evaluates `eval`
requests, and `WifiSecurityType.toString(i)`-style calls reveal enum names.

### Services API quirks (verified on 0.3.1)
- `Pipewire`, `Networking`, `UPower`, `SystemTray` are **singletons** — never
  instantiate them.
- Pipewire volume/mute live at `Pipewire.defaultAudioSink.audio.volume/muted`
  and only bind with a `PwObjectTracker { objects: [...] }` present.
- UPower populates ~3s after launch: gate on `displayDevice.ready`, and
  `percentage` is 0–1 (multiply by 100). `timeToEmpty`/`timeToFull` are seconds.
- Module paths: Bluetooth is `Quickshell.Bluetooth` (not `Services.`); tray
  methods are `activate()`, `secondaryActivate()`, `scroll(delta, horizontal)`,
  `display(win, x, y)`; menus come from the `menu` handle.
- Enums read as `TypeName.Value` (`DeviceType.Wifi`, `ConnectionState.Connected`
  = 2, `UPowerDeviceState.Charging` = 1, `BluetoothDeviceState.Connected` = 1,
  `WifiSecurityType.Open` = 10). qmltypes files are incomplete/empty (Hyprland,
  Widgets) — types still exist at runtime.
- `Mpris` / `MprisPlayer` (`Quickshell.Services.Mpris`, qmltypes complete):
  `Mpris.players` is an ObjectModel — iterate via `Mpris.players.values` (same
  as `Networking.devices.values`). `playbackState` is
  `MprisPlaybackState.Stopped/Playing/Paused`; `trackArtists` is a single
  QString (NOT a list, despite the name — same backing as `trackArtist`);
  `trackArtUrl` is a plain URL usable directly in an `Image`; transport
  methods `togglePlaying()/next()/previous()` guarded by
  `canTogglePlaying/canGoNext/canGoPrevious`.
- `NotificationServer` / `Notification` (`Quickshell.Services.Notifications`,
  qmltypes complete): server is instantiable (NOT a singleton), has NO
  do-not-disturb property (DND is our own state in `Notifs`). `Notification`
  has `tracked` (writable — MUST be set true, see gotcha), `expireTimeout`
  (ms), `urgency` (Low/Normal/Critical), methods `expire()`/`dismiss()`.
- QML files in this dir require a `qmldir` entry each; singleton + component
  listing the same file twice fails to load; QML property names cannot start
  with an uppercase letter.
