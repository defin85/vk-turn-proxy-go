# Desktop GUI Shell

`desktop/gui_shell` is the first Flutter desktop shell for `vk-turn-proxy-go`.
It is a GUI over the local client control plane, not a second runtime implementation.

## Scope

- manage saved profiles
- transfer saved profiles across shells through explicit portable-profile file,
  text, and QR actions
- resolve live provider links into typed handoff records
- start the same-device runtime path from a resolved handoff without manual secret copy/paste
- start and stop sessions through `cmd/clientd`
- surface typed session state and challenge events
- optionally copy the explicit handoff link for support or cross-device use
- export per-session diagnostics bundles
- supervise a compatible local sidecar on Windows, macOS, and Linux

## Workspace model

The default desktop shell now reads as one workflow-oriented workspace instead
of a dashboard of peer cards:

- large desktop widths keep a persistent left pad for workflow switching, task
  entry, and active-selection cues
- narrower desktop widths collapse the same command set into a drawer without
  changing the active canvas route, draft, or selection
- profile library, managed-provider browsing, preset bootstrap, and provider
  family choice open as dedicated main-canvas routes with an explicit in-canvas
  back path
- diagnostics and live work stay secondary through the inspector instead of
  replacing the main editor canvas

That layout keeps the dominant path compact in ready state: choose context,
edit the active draft or managed record, then resolve or start from the same
canvas.

## Local development

From the repository root:

```bash
dart pub get
cd desktop/gui_shell
flutter analyze
flutter test
flutter run -d linux
flutter build linux
```

For screenshot/automation flows that need the Flutter driver extension, use the
separate automation entrypoint instead of the normal app target:

```bash
cd desktop/gui_shell
flutter run -d linux -t test_driver/driver_main.dart
```

That target enables `flutter_driver` automation hooks for tools that need
driver actions or app screenshots, while keeping the default `lib/main.dart`
path free of automation-only behavior. The automation target keeps real
keyboard input enabled; if a tool needs `FlutterDriver.enterText`, toggle text
entry emulation explicitly for that session instead of baking it into the app
entrypoint.

The current shell is verified on Linux.
The project also includes generated `macos/` and `windows/` runners so packaging and sidecar placement can follow the same control-plane contract there.
The repository-root Dart workspace owns dependency resolution for this shell: keep using the root `pubspec.lock`, and rerun `dart pub get` from the repo root after dependency changes or a fresh checkout.

The pinned Flutter SDK version for this project is stored in `desktop/gui_shell/.flutter-version`.
The canonical product version source for supported builds is `version.json` at the repository root.
The canonical publish-facing native identifier source is `publish_identity.json` at the repository root.
Keep the Flutter-facing defaults aligned with that manifest through:

```bash
./scripts/sync-version-assets.py
```

Keep publish-facing native identifiers aligned through:

```bash
./scripts/sync-publish-identity.py
```

For Windows packaging from the canonical WSL checkout, use the repo-owned wrapper instead of running Flutter directly from `\\wsl.localhost\...`:

```bash
./scripts/build-windows-gui-from-wsl.sh
```

That workflow synchronizes the repository into `E:\Projects\vk-turn-proxy-go`, runs the Windows-native Flutter build there, and stages the packaged bundle under `dist/windows-gui/`.
It also refreshes the mirrored build metadata stamp used by the direct native Windows build path when the mirror has no `.git` checkout.

For the validated Windows desktop `WireGuard` PoC, use the mirrored Windows
bundle directly from `E:\Projects\vk-turn-proxy-go\dist\windows-gui` and follow
`docs/windows-desktop-wg-poc.md`.
That document captures the required host route, the `WireGuard` profile shape,
the repo-owned `scripts/run-windows-gui-shell.ps1` helper that starts a fresh
bundled `clientd.exe` before `RelayDock.exe`, waits for the GUI to exit, and
then stops the owned sidecar, and the companion
`scripts/windows-desktop-generic-turn.ps1` helper that seeds and starts the
desktop `generic-turn` session through the local control plane.

For the packaged Windows workflow that starts from a real VK invite inside the
desktop GUI, moves through typed resolution and browser continuation when
needed, and then starts the same-device desktop session, follow
`docs/windows-desktop-live-vk-workflow.md`.
The canonical actor model and invite-first workflow contract live in
`docs/vk-invite-user-workflow.md`.

For the supported Ubuntu `linux_tun` package, use the repo-owned Linux build
entrypoint from the repository root:

```bash
make build-gui-linux
sudo dist/linux-gui/install-ubuntu.sh
/opt/relaydock/relaydock
```

That package stages the GUI, sibling `clientd` launcher, real host binary,
privileged wrapper, polkit action, and build metadata together. Raw local
Flutter bundles and `go run ./cmd/clientd` remain development paths, not the
Linux `linux_tun` support surface.

## Control-plane contract

The shell talks to `cmd/clientd` on `127.0.0.1:7777` through the versioned HTTP surface from `pkg/clientcontrol`.
The required host capabilities for this shell are:

- `desktop_sidecar`
- `platform_tunnels`
- `profiles`
- `provider-runtime-artifacts`
- `runtime-execution-planning`
- `sessions`
- `challenges`
- `diagnostics`
- `event_stream`

If negotiation fails because the host is missing one of those capabilities or reports an incompatible version, the shell blocks session management and reports the incompatibility explicitly.
When host metadata is available, the banner shows the local GUI build identity, the connected host build identity, and the control-plane contract version as distinct values.
Host metadata may also include `platform_tunnels`, a typed per-mode report for `windows_wintun`, `linux_tun`, or `apple_network_extension` depending on the packaged host target.
When the host also advertises `runtime-execution-planning`, host-owned same-device actions and per-mode tunnel reports expose typed execution plans instead of one implicit desktop-VPN mode string.
Current repo-owned desktop startup still defaults to the documented TURN-backed `custom_packet_overlay` plan, while packaged system-tunnel plans stay explicitly scoped to TURN-backed `wireguard_native` and fail closed until a platform sidecar implements them.
The shell renders that report in the dashboard and uses the typed `/v1/platform-tunnels/start` result instead of inferring system-tunnel support from OS or bundle heuristics.
Operators can request startup for the reported mode directly from the shell to inspect the stage-aware fail-closed result in-app.
Current repo-owned desktop hosts still fail closed for those modes until a platform-specific sidecar implements the privileged tunnel path.

## Invite resolution workflow

The desktop shell now supports the product path:

1. paste a shared provider link such as a VK invite in the profile editor
2. click `Resolve invite`
3. if the host reports `challenge_required`, complete the browser step and then click `Continue after browser step`
4. finish the provider flow past preview and click `Join` before expecting the handoff to become usable
5. wait for the typed resolution card to reach `resolved`
6. choose either `Start on this device` for the normal desktop runtime path or `Copy handoff` for explicit export

`Start on this device` reuses the non-secret runtime defaults from the profile
editor, such as listen address, peer address, transport policy, and TURN
override fields, without requiring the full secret handoff link to be pasted
back into the same host.
Those runtime defaults stay operator-managed in the standard VK flow; the end
user path is invite-first, not peer-first.

## Sidecar discovery order

The desktop host supervisor resolves or launches `clientd` in this order:

1. `GUI_SHELL_CLIENTD_PATH`
2. a bundled `clientd` binary next to the GUI executable
3. `Frameworks/clientd` inside the macOS app bundle
4. `clientd` from `PATH`
5. `go run ./cmd/clientd -listen 127.0.0.1:7777` from the repository root during development

That order lets packaged builds stay self-contained while keeping local repository development friction low.
If a launched candidate exits or negotiates as incompatible, the supervisor disposes it and continues to the next candidate instead of stopping at the first failed launch.

## Packaging behavior

- Linux: package the GUI binary with a sibling `clientd` launcher that uses the
  staged polkit wrapper and real `libexec/clientd` host from the Ubuntu package.
- Windows: package `clientd.exe` next to the GUI executable.
- macOS: package the sidecar in `YourApp.app/Contents/Frameworks/clientd`.
- All desktop platforms: keep the control plane loopback-only and keep the GUI talking to a compatible host rather than embedding runtime code in the UI process.

## Local shell state

The desktop shell persists:

- saved profiles
- the selected profile
- the current in-progress draft
- the non-secret runtime defaults used for `Start on this device`

Default state-file paths:

- Linux and macOS: `~/.vk-turn-proxy-go/gui-shell-state.json`
- Windows: `%APPDATA%\\vk-turn-proxy-go\\gui-shell-state.json`

When the GUI reconnects to a compatible host, it rehydrates the persisted profiles back into the local control plane before normal profile/session refresh continues.
The persisted plaintext state keeps the same-device runtime defaults separate
from secret-bearing provider input links; invite URLs, room/bootstrap tokens,
and `generic-turn://...` handoff credentials are cleared before the plaintext
state file is written. The non-secret canonical VK hosted-call root link
`https://calls.vk.com/` is retained so a saved authenticated VK profile can be
restored after a GUI restart without retyping the provider start URL.

## Portable profile transfer

Saved profiles now support a second explicit transfer path that stays distinct
from both ordinary shell persistence and runtime handoff export:

- `Export saved profile` in the profile workspace builds one versioned
  portable-profile envelope from the saved profile plus any managed-provider
  snapshot required to restore its managed/custom source mode on another shell
- the desktop shell can copy that envelope as text, save it as a `.json` file,
  and render the same payload as QR when the encoded envelope fits the shared
  QR bounds
- if the payload is too large for QR, the shell fails closed for QR and keeps
  file/text export available instead of truncating the payload
- desktop import accepts either a selected file or pasted JSON envelope, always
  shows a preview before confirmation, allocates fresh local ids, restores
  managed-provider bindings from the embedded snapshot, and never auto-starts
  runtime or overwrites an unrelated local profile
- secret-bearing portable envelopes are warned explicitly before copy, save, QR
  rendering, or import confirmation

This portable transfer path is not the same as `Copy handoff`.
`Copy handoff` still exports a short-lived runtime artifact from a resolved
resolution card, while portable profile transfer exports a saved profile
workspace snapshot for shell-to-shell reuse.

## Challenge, tray, and notifications behavior

Browser continuation stays host-driven.
When the operator clicks `Continue in browser`, the shell calls the typed challenge endpoint and reflects the resulting session events back into the UI; provider-specific browser logic remains outside the Flutter layer.
If the shell reconnects while a session still has an active challenge, it reloads that challenge snapshot from the control plane instead of depending only on in-memory event history.

This change does not introduce a background-only tray runtime or platform-specific notification engine.
The desktop shell keeps runtime control explicit through visible in-app status banners, session cards, and action buttons so that desktop UX does not diverge from control-plane semantics.

If the local host disappears after the GUI is already ready, the shell moves back to a blocked state, pauses session actions, and re-runs compatible host discovery before requiring a manual reconnect.

## Diagnostics export

The shell writes one JSON diagnostics bundle per session.
Default export paths:

- Linux and macOS: `~/.vk-turn-proxy-go/diagnostics`
- Windows: `%APPDATA%\\vk-turn-proxy-go\\diagnostics`

Diagnostics bundles come from the host and include the typed session snapshot, recent events, active challenges, and metrics text for that session.
On export, the GUI also persists its own build identity alongside the host build identity and contract version so support bundles preserve the same version context shown in the shell.
