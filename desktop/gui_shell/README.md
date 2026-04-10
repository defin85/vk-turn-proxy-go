# Desktop GUI Shell

`desktop/gui_shell` is the first Flutter desktop shell for `vk-turn-proxy-go`.
It is a GUI over the local client control plane, not a second runtime implementation.

## Scope

- manage saved profiles
- start and stop sessions through `cmd/clientd`
- surface typed session state and challenge events
- export per-session diagnostics bundles
- supervise a compatible local sidecar on Windows, macOS, and Linux

## Local development

From the repository root:

```bash
cd desktop/gui_shell
flutter analyze
flutter test
flutter run -d linux
flutter build linux
```

The current shell is verified on Linux.
The project also includes generated `macos/` and `windows/` runners so packaging and sidecar placement can follow the same control-plane contract there.

The pinned Flutter SDK version for this project is stored in `desktop/gui_shell/.flutter-version`.
The canonical product version source for supported builds is `version.json` at the repository root.
Keep the Flutter-facing defaults aligned with that manifest through:

```bash
./scripts/sync-version-assets.py
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
and the repo-owned `scripts/run-windows-gui-shell.ps1` helper that starts a
fresh bundled `clientd.exe` before `gui_shell.exe`.

## Control-plane contract

The shell talks to `cmd/clientd` on `127.0.0.1:7777` through the versioned HTTP surface from `pkg/clientcontrol`.
The required host capabilities for this shell are:

- `desktop_sidecar`
- `profiles`
- `sessions`
- `challenges`
- `diagnostics`
- `event_stream`

If negotiation fails because the host is missing one of those capabilities or reports an incompatible version, the shell blocks session management and reports the incompatibility explicitly.
When host metadata is available, the banner shows the local GUI build identity, the connected host build identity, and the control-plane contract version as distinct values.
Host metadata may also include `platform_tunnels`, a typed per-mode report for `windows_wintun`, `linux_tun`, or `apple_network_extension` depending on the packaged host target.
The shell renders that report in the dashboard and uses the typed `/v1/platform-tunnels/start` result instead of inferring system-tunnel support from OS or bundle heuristics.
Operators can request startup for the reported mode directly from the shell to inspect the stage-aware fail-closed result in-app.
Current repo-owned desktop hosts still fail closed for those modes until a platform-specific sidecar implements the privileged tunnel path.

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

- Linux: package the GUI binary with a sibling `clientd` binary.
- Windows: package `clientd.exe` next to the GUI executable.
- macOS: package the sidecar in `YourApp.app/Contents/Frameworks/clientd`.
- All desktop platforms: keep the control plane loopback-only and keep the GUI talking to a compatible host rather than embedding runtime code in the UI process.

## Local shell state

The desktop shell persists:

- saved profiles
- the selected profile
- the current in-progress draft

Default state-file paths:

- Linux and macOS: `~/.vk-turn-proxy-go/gui-shell-state.json`
- Windows: `%APPDATA%\\vk-turn-proxy-go\\gui-shell-state.json`

When the GUI reconnects to a compatible host, it rehydrates the persisted profiles back into the local control plane before normal profile/session refresh continues.

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
