# Mobile GUI Shell Instructions

## Read First

- `mobile/gui_shell/README.md`
- `openspec/specs/mobile-gui-client/spec.md`
- `openspec/specs/android-embedded-mobile-host/spec.md`
- `openspec/specs/platform-tunnel-integration/spec.md`

## Guardrails

- Keep the mobile shell fail-closed when the native bridge or packaged host is missing or incompatible.
- Do not imply device-wide VPN or tunnel support unless the typed platform-tunnel contract and specs explicitly support it.
- Keep provider input links and other secret-bearing values out of persisted plaintext state.
- Keep browser continuation semantics aligned with host-reported challenge metadata instead of shell-local guesses.

## Verification

- Run `dart pub get` from the repository root before shell-local checks.
- Run `cd mobile/gui_shell && flutter analyze && flutter test`.
- If packaged-host or bridge semantics change, also run `go test ./internal/androidembeddedhost ./pkg/clientcontrol`.

## Preferred Debug Loop

- Prefer Dart MCP as the primary mobile UI loop.
- Use the dedicated mobile namespace for this app: `mcp__dart_mobile__`.
- For normal agent-operated mobile UI inspection, screenshots, and taps, launch the app with `mcp__dart_mobile__.launch_app(device="<adb-serial>", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/driver_main.dart")`.
- When ADB-over-Wi-Fi is unavailable or unstable on this workstation, use the verified USB alternative: attach the Android ADB interface into WSL with Windows `usbipd attach --wsl --busid <busid> --auto-attach`, confirm `adb devices -l` in WSL shows the USB serial, then use that serial in `mcp__dart_mobile__.launch_app(...)`.
- Always use the driver-extension entrypoint for Dart MCP launches. Do not omit `target="test_driver/driver_main.dart"` unless the user explicitly asks for a production-entrypoint parity run and accepts that Flutter Driver screenshots/taps will be unavailable.
- Pass a plain filesystem path to `launch_app.root`; do not pass a `file://...` URI.
- After `launch_app` returns a DTD URI, connect `mcp__dart_mobile__` to that URI and use `hot_reload`, runtime-error reads, widget inspection, and `flutter_driver` screenshot or tap commands against that live process.
- For Android owned-browser or keyboard regressions, prefer the repo-owned harness target `mcp__dart_mobile__.launch_app(device="<adb-serial>", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/owned_browser_harness_main.dart")` before inventing a custom repro app.
- The harness keeps a local `_showHarnessDiagnostics` toggle. Leave it `false` for normal runs and only enable it for the current debugging task when native/DOM IME diagnostics are needed.
- This namespace keeps one active DTD connection at a time. If you need to replace an existing mobile DTD inside `mcp__dart_mobile__`, use a fresh Codex session.
- Do not fall back to `adb`-driven install/logcat/forward/input steps unless the user explicitly agrees to leave the Dart MCP loop in the current thread.
