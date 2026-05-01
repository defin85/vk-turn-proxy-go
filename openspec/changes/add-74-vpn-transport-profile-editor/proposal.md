# Change: Add structured VPN transport profile editor

## Why

`add-73-vpn-transport-profile-store` made VPN transport material host-owned and
safe to reference by profile id, but the shipped shell workflow still only
imports, replaces, or forgets a WireGuard `.conf`. That is not enough for a
product operator: creating or correcting a VPN transport profile still requires
an external file editor and an already available `.conf`.

## What Changes

- Extend the VPN transport profile store contract with structured editable
  profile schemas and create/update operations for `wireguard_native_v1`.
- Keep WireGuard `.conf` import as a convenience adapter, not as the only
  configuration path.
- Add mobile and desktop GUI profile editor surfaces for display name,
  interface addresses, DNS, MTU, peer public key, allowed IPs, endpoint, and
  host-supported optional WireGuard fields such as persistent keepalive.
- Preserve the add-73 security boundary: ordinary reads stay redacted, startup
  uses profile references, and secret-bearing material remains host-owned.
- Add field-aware validation so invalid or unsupported profile parameters fail
  before replacing a startable profile.

## Impact

- Affected specs:
  - `vpn-transport-profile-store`
  - `client-control-plane`
  - `mobile-gui-client`
  - `desktop-gui-client`
  - `desktop-sidecar-host`
  - `android-embedded-mobile-host`
  - `wireguard-turn-carrier`
- Affected code:
  - `pkg/clientcontrol`
  - `internal/wireguardprofile`
  - `internal/androidembeddedhost`
  - `internal/androidplatformbridge`
  - `internal/windowsdesktophost`
  - `packages/flutter_shell_core`
  - `mobile/gui_shell`
  - `desktop/gui_shell`
- Depends on:
  - `add-73-vpn-transport-profile-store` profile-store capability, profile ids,
    redaction guarantees, and startup profile references.
