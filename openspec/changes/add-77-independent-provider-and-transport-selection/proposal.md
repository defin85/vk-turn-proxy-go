# Change: [77] Add independent provider and VPN transport selection

## Why

RelayDock's product model must not collapse external provider contours and
local VPN transport profiles into one mixed "connection profile" surface.

Operators need one place to choose the external source or carrier contour, such
as VK TURN, WB TURN, Yandex Telemost, SFU, or Rostelecom video paths, and a
separate place to choose local VPN transport material, such as WireGuard,
V2Ray, SOCKS5, Hysteria, or QUIC-based profiles. Runtime startup then combines
those choices only through an explicit compatibility matrix.

## Sequence

- Order: `77`
- Depends on: archived VPN transport profile store/editor work and current
  runtime-execution-planning contracts
- Relates to: `add-57` through `add-60` multitransport planning and flow-6/7
  provider expansion proposals

## What Changes

- Define provider or contour sources and VPN transport profiles as independent
  user-facing catalogs.
- Require shells to let operators choose a provider source and a VPN transport
  profile independently, then show compatibility before startup.
- Require the control plane and runtime execution planning layer to combine
  those selections through typed provider artifact, carrier, engine, host
  adapter, and profile-kind compatibility metadata.
- Prevent provider records from storing VPN transport secrets or implicit VPN
  defaults, and prevent VPN transport profiles from storing provider
  credentials or contour-specific signaling state.
- Keep unsupported combinations visible as incompatible or setup-needed rather
  than silently substituting another provider source or transport profile.

## Impact

- Affected specs: `provider-runtime-artifacts`,
  `vpn-transport-profile-store`, `runtime-execution-planning`,
  `client-control-plane`, `mobile-gui-client`, `desktop-gui-client`
- Affected code: future provider-source catalog UI, VPN transport profile
  manager filtering, runtime plan selection, compatibility diagnostics, and
  shell state persistence

## Assumptions

- "Provider source" names the external contour or artifact source, not the
  local VPN engine.
- "VPN transport profile" names local engine material and host-owned startup
  material, not provider signaling.
- A saved product profile may remember operator intent for both axes, but each
  axis stays separately editable and separately validated.
