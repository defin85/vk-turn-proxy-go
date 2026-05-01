# Change: Add schema-driven VPN transport profile kinds

## Why

RelayDock now owns native VPN management, but the startable product path and
profile editor are still effectively tied to `wireguard_native_v1`.
That is acceptable for the first shipped path, but it would make a later VPN
transport such as `openvpn_userspace_v1`, `native_os_vpn_v1`, or a managed
provider tunnel feel bolted on and would force more UI rewrites than the
profile-store contract intended.

## Sequence

- Order: `76`
- Depends on: `add-73-vpn-transport-profile-store`,
  `add-74-vpn-transport-profile-editor`,
  `add-75-relaydock-native-vpn-management`
- Blocks: claiming RelayDock can manage non-WireGuard VPN transport profiles
  from the same product UI

## What Changes

- Make VPN transport profile kinds host-advertised, schema-driven values in
  shell/control-plane clients instead of closed WireGuard-only enums.
- Replace the WireGuard-specific structured editor surface with a reusable
  schema renderer that respects host-advertised field descriptors, value kinds,
  secret update actions, lifecycle actions, and import adapters.
- Add a RelayDock VPN transport profile manager/list surface for multiple
  profiles, scoped by required kind and execution plan, instead of treating the
  editor as a single implicit current-profile form.
- Keep `wireguard_native_v1` as the only supported native VPN transport until a
  later change implements and verifies another concrete kind.
- Require runtime execution plans to bind any future non-WireGuard VPN engine
  to explicit profile-kind prerequisites and host/native adapter evidence.
- Keep Home as the only primary VPN connect/disconnect owner while Routing and
  diagnostics remain status/setup surfaces.

## Impact

- Affected specs:
  - `vpn-transport-profile-store`
  - `client-control-plane`
  - `runtime-execution-planning`
  - `mobile-gui-client`
  - `desktop-gui-client`
  - `platform-tunnel-integration`
- Affected code:
  - `pkg/clientcontrol` transport profile and runtime execution models
  - `packages/flutter_shell_core` runtime/profile models and profile editor UI
  - `mobile/gui_shell` and `desktop/gui_shell` profile setup surfaces
  - platform tunnel host adapters when a later concrete non-WireGuard kind is
    introduced
