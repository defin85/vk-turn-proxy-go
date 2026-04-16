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

- Prefer WSLg with the Linux target for day-to-day desktop UI iteration.
- Start the local host in WSL with `go run ./cmd/clientd -listen 127.0.0.1:7777` before launching the shell when you need real control-plane behavior.
- Run `dart pub get` from the repository root, then launch the shell with `mcp__dart__.launch_app(device="linux", root="/home/egor/code/vk-turn-proxy-go/desktop/gui_shell")`.
- Pass a plain filesystem path to `launch_app.root`; do not pass a `file://...` URI.
- Keep both the Flutter shell and `clientd` in the same WSL environment for the default debug loop; do not mix the Linux shell with the Windows sidecar for routine UI work.
- After `launch_app` returns a DTD URI, connect Dart MCP to that URI and use MCP `hot_reload`, widget-tree inspection, runtime-error reads, and driver interactions against that live process.
- Dart MCP currently keeps one active DTD connection per Codex session. Use a fresh Codex session before switching this tooling connection between desktop and mobile targets.
- For screenshot or Flutter Driver automation, use `cd desktop/gui_shell && flutter run --machine -d linux -t test_driver/driver_main.dart`.
- Keep `test_driver/driver_main.dart` on real keyboard input by calling `enableFlutterDriverExtension(enableTextEntryEmulation: false)`; otherwise the live WSLg window stops accepting normal manual typing.
- If a tool needs `FlutterDriver.enterText`, toggle text-entry emulation explicitly for that automation session and disable it again afterwards instead of changing the default entrypoint behavior.
- Escalate to the Windows mirror workflow only for Windows-specific rendering, packaging, host-supervision, or bundled-sidecar checks.
