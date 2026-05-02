# Change: Add RelayDock-native VPN management

## Why

`add-74-vpn-transport-profile-editor` closes the structured profile editor,
store, validation, and materialization contract. Product acceptance still needs
RelayDock itself to own Android VPN management: configure, start, resume after
Android permission, show status, and disconnect without sending the operator to
the external WireGuard Android application.

The external WireGuard-app phone workflow remains useful as a legacy transport
PoC, but it does not prove one-app RelayDock VPN support or the
`android_vpn_service` runtime path.

## What Changes

- Add a RelayDock-owned native Android VPN lifecycle from structured
  `wireguard_native_v1` profile through resolved TURN artifact to
  `android_vpn_service`.
- Keep transport, WireGuard, TUN, crypto, and socket plumbing behind the
  embedded host/native adapter boundary, where ready-made libraries may be used.
- Keep the mobile GUI as a typed consumer that drives setup, start, permission
  resume, ready status, diagnostics, and disconnect through the control plane.
- Treat external WireGuard Android app workflows as compatibility/PoC evidence
  only, never as product acceptance for native VPN management.
- Require device or emulator verification proving the direct native path.

## Impact

- Affected specs: `mobile-gui-client`, `android-embedded-mobile-host`,
  `client-control-plane`, `platform-tunnel-integration`
- Affected code: `mobile/gui_shell`, `packages/flutter_shell_core`,
  `pkg/clientcontrol`, `internal/androidembeddedhost`,
  `internal/wireguardturnruntime`, Android native adapter/bridge code, and
  repo-owned Android verification scripts
- Depends on: `add-74-vpn-transport-profile-editor`,
  `add-73-vpn-transport-profile-store`,
  `android-vpnservice-host-boundary`, `wireguard-turn-carrier`, and
  `runtime-execution-planning`
