# DEBUG

Verified UI development loops for this repository. Only techniques that were exercised in the current workspace belong here.

## Dart MCP rules

- `mcp__dart__.launch_app.root` must be a plain filesystem path like `/home/egor/code/vk-turn-proxy-go/mobile/gui_shell`.
- Do not pass `file://...` URIs to `launch_app.root`; that fails before launch.
- One Codex session can hold only one active Dart Tooling Daemon connection.
- After you connect to one app DTD, switching to another UI target requires a fresh Codex session.
- Treat `adb` as an explicit fallback path. Do not drop to `adb`-driven install/logcat/forward/input work unless the user has agreed to that switch in the current thread.

## Mobile GUI shell via Dart MCP

Verified on `2026-04-17` against Android device `192.168.0.16:40017`.

1. Launch with Dart MCP:
   `mcp__dart__.launch_app(device="192.168.0.16:40017", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/driver_main.dart")`
2. Connect to the returned DTD URI with `mcp__dart__.connect_dart_tooling_daemon`.
3. Use `mcp__dart__.hot_reload` for iteration.
4. Use `mcp__dart__.flutter_driver(command="screenshot")` and other `flutter_driver` commands for live screenshots and taps.

Verified evidence:
- `launch_app` returned a live DTD URI and PID for the mobile app.
- `hot_reload` succeeded.
- `flutter_driver(command="screenshot")` returned a real screenshot from the device.
- `flutter_driver(command="tap", finderType="ByText", text="Providers")` successfully switched the app to `Providers`.
- A follow-up screenshot showed the live wide-layout `Providers` screen with the saved-provider root on the left and the companion create pane on the right.

Use the default `mobile/gui_shell/lib/main.dart` entrypoint only when the task specifically needs production-entrypoint parity rather than driver-enabled inspection.

### Mobile GUI shell via Dart MCP over USB from WSL

Verified on `2026-04-17` against the same Android tablet after moving from
ADB-over-Wi-Fi to USB passthrough into WSL.

Host-side prerequisites:
- Windows must have `usbipd-win` installed and the tablet's ADB interface must
  be visible in `usbipd list`.
- The current workstation verified this with Xiaomi Pad 5 in ADB mode
  `VID:PID 2717:ff48`.
- The tablet must keep `USB debugging` enabled and, when MIUI prompts for a
  USB mode during attach, the stable choice on this workstation was
  `Передача файлов / Android Auto` rather than `Без передачи данных` or `PTP`.
- WSL needs a matching `udev` rule so the Linux `adb` can open the USB node
  without a manual `chmod` or `chgrp` step:
  `SUBSYSTEM=="usb", ATTR{idVendor}=="2717", ATTR{idProduct}=="ff48", MODE="0660", GROUP="wheel"`
  in `/etc/udev/rules.d/51-xiaomi-adb.rules`.

Verified Windows-to-WSL USB preparation:
1. Share the current ADB interface once from elevated Windows PowerShell:
   `usbipd bind --busid <busid>`
2. Keep the USB passthrough active from Windows PowerShell:
   `usbipd attach --wsl --busid <busid> --auto-attach`
3. Confirm the Linux-side ADB target exists in WSL:
   `adb devices -l`

Verified Dart MCP loop after USB attach:
1. Launch with Dart MCP from WSL:
   `mcp__dart__.launch_app(device="<usb-serial>", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/driver_main.dart")`
2. Connect to the returned DTD URI with `mcp__dart__.connect_dart_tooling_daemon`.
3. Use `mcp__dart__.hot_reload`.
4. Use `mcp__dart__.flutter_driver(command="screenshot")` and other driver
   commands against the USB target.

Verified evidence:
- `usbipd attach --wsl --auto-attach` delivered the Android ADB interface into
  WSL as a real USB ADB device.
- `adb devices -l` in WSL reported the tablet as `device` with serial
  `b2bc0e37`.
- Dart MCP `list_devices` exposed the USB target as `b2bc0e37`.
- `launch_app`, `connect_dart_tooling_daemon`, `hot_reload`, and
  `flutter_driver(command="get_health")` all succeeded against that USB target.

Operational notes:
- Keep the `usbipd attach --wsl --auto-attach ...` PowerShell session alive
  while using the USB path; it handles MIUI-triggered USB re-enumeration.
- If the USB interface changes after reconnecting the cable, rerun
  `usbipd list` and use the new `BUSID`.
- The USB path is the verified alternative to ADB-over-Wi-Fi for mobile Dart
  MCP work from WSL. It is still a Windows-assisted passthrough step, not a
  pure WSL-only attach path.

### Mobile owned-browser IME harness

Verified on `2026-04-16` against the same Android tablet.

1. Launch the harness instead of the normal driver entrypoint:
   `mcp__dart__.launch_app(device="192.168.0.16:40017", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/owned_browser_harness_main.dart")`
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
