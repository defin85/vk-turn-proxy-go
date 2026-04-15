# Desktop GUI Shell Instructions

## Read First

- `desktop/gui_shell/README.md`
- `openspec/specs/desktop-gui-client/spec.md`
- `openspec/specs/platform-tunnel-integration/spec.md`
- `.agents/skills/vk-turn-desktop-shell/SKILL.md`

## Guardrails

- Keep host and platform-tunnel state fail-closed and explicit in the UI.
- Keep diagnostics and live-work surfaces secondary to the main profile and resolve/start workflow.
- Do not move provider-specific browser logic into the Flutter layer.
- Prefer workflow-first pane composition over dashboard-style peer-card layouts.

## Verification

- Run `dart pub get` from the repository root before shell-local checks.
- Run `cd desktop/gui_shell && flutter analyze && flutter test`.
- If host negotiation or sidecar behavior changes, also run `go test ./pkg/clientcontrol ./cmd/clientd`.

## Preferred Debug Loop

- Prefer WSLg with `flutter run --machine -d linux` for day-to-day desktop UI iteration.
- Start the local host in WSL with `go run ./cmd/clientd -listen 127.0.0.1:7777` before launching the shell when you need real control-plane behavior.
- Run `dart pub get` from the repository root, then launch the shell with `cd desktop/gui_shell && flutter run --machine -d linux`.
- Keep both the Flutter shell and `clientd` in the same WSL environment for the default debug loop; do not mix the Linux shell with the Windows sidecar for routine UI work.
- After the app starts, prefer Dart MCP as the control layer: connect to the `app.dtd` URI from Flutter machine output and use MCP `hot_reload`, widget-tree inspection, runtime-error reads, and driver interactions against that live process.
- For screenshot or Flutter Driver automation, use `cd desktop/gui_shell && flutter run --machine -d linux -t test_driver/driver_main.dart`.
- Keep `test_driver/driver_main.dart` on real keyboard input by calling `enableFlutterDriverExtension(enableTextEntryEmulation: false)`; otherwise the live WSLg window stops accepting normal manual typing.
- If a tool needs `FlutterDriver.enterText`, toggle text-entry emulation explicitly for that automation session and disable it again afterwards instead of changing the default entrypoint behavior.
- Treat Dart MCP `launch_app` as secondary for Linux desktop until it is re-verified in the active WSLg environment; if it fails with `cannot open display`, fall back to the direct `flutter run --machine` launch above.
- Escalate to the Windows mirror workflow only for Windows-specific rendering, packaging, host-supervision, or bundled-sidecar checks.
