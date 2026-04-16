# DEBUG

Verified UI development loops for this repository. Only techniques that were exercised in the current workspace belong here.

## Dart MCP rules

- `mcp__dart__.launch_app.root` must be a plain filesystem path like `/home/egor/code/vk-turn-proxy-go/mobile/gui_shell`.
- Do not pass `file://...` URIs to `launch_app.root`; that fails before launch.
- One Codex session can hold only one active Dart Tooling Daemon connection.
- After you connect to one app DTD, switching to another UI target requires a fresh Codex session.
- Treat `adb` as an explicit fallback path. Do not drop to `adb`-driven install/logcat/forward/input work unless the user has agreed to that switch in the current thread.

## Mobile GUI shell via Dart MCP

Verified on `2026-04-16` against Android tablet `192.168.0.16:39305`.

1. Launch with Dart MCP:
   `mcp__dart__.launch_app(device="192.168.0.16:39305", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell")`
2. Connect to the returned DTD URI with `mcp__dart__.connect_dart_tooling_daemon`.
3. Use `mcp__dart__.hot_reload` for iteration.

Verified evidence:
- `launch_app` returned a live DTD URI and PID for the tablet app.
- `hot_reload` succeeded.
- A temporary title change from `Home` to `Home MCP` appeared on the real device screenshot after `hot_reload`.
- Reverting that title and running `hot_reload` again restored the original UI.

### Mobile owned-browser IME harness

Verified on `2026-04-16` against the same Android tablet.

1. Launch the harness instead of the default app entrypoint:
   `mcp__dart__.launch_app(device="192.168.0.16:39305", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/owned_browser_harness_main.dart")`
2. Connect to the returned DTD URI with `mcp__dart__.connect_dart_tooling_daemon`.
3. Use `mcp__dart__.hot_reload` and reopen the harness route to iterate on the owned-browser `WebView` path.
4. If the current task needs live native/DOM diagnostics, temporarily flip `_showHarnessDiagnostics` in `mobile/gui_shell/test_driver/owned_browser_harness_main.dart` to `true`, `hot_reload`, and reopen the route. Turn it back off afterwards.

Verified evidence:
- The harness auto-opened a live VK auth page inside the app-owned `WebView`.
- A `flutter_driver.tap` on `AndroidViewSurface` reached the real IME path on the device.
- Native debug snapshots showed `inputCalls=1`, `ime visible=true`, and `noFullscreen=true` plus `noExtract=true` on the live `WebView`.
- Tapping `Hide keyboard` returned the route to `ime visible=false`.
- With `_showHarnessDiagnostics=false`, the harness reopened cleanly and `owned-browser-debug-panel` was absent.

## Desktop GUI shell via Dart MCP

Verified on `2026-04-16` against Linux desktop target under WSLg.

1. Start the local control plane first:
   `go run ./cmd/clientd -listen 127.0.0.1:7777`
2. Launch with Dart MCP:
   `mcp__dart__.launch_app(device="linux", root="/home/egor/code/vk-turn-proxy-go/desktop/gui_shell")`
3. Connect to the returned DTD URI in a fresh Codex session dedicated to the desktop target.

Verified evidence:
- `clientd` reached `listening` on `127.0.0.1:7777`.
- `launch_app` built and started the Linux desktop shell and returned a live DTD URI and PID.
- In the same Codex session, `hot_reload` against the desktop target remained blocked because Dart MCP refused to replace an existing mobile DTD connection.

Local workstation prerequisite:
- The local Flutter launcher at `/opt/flutter/bin/flutter` must preserve or restore WSLg display variables when Dart MCP launches Flutter without them.
- On this workstation the launcher now restores `DISPLAY`, `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, and `PULSE_SERVER` when those are missing but the standard WSLg sockets are present.

## Verified regression checks

- `cd mobile/gui_shell && flutter test test/widget_test.dart --plain-name 'owned-browser page yields shell chrome to web content while keyboard is visible even after a web resource error'`
- `mcp__dart__.hot_reload` on the live mobile app after a real source edit
- `mcp__dart__.launch_app` for both mobile and desktop targets
