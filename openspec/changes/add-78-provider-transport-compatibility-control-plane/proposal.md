# Change: [78] Add provider/transport compatibility control plane

## Why

`add-77` locks the product model as two independent operator axes: provider or
contour sources on one side, VPN transport profiles on the other. The next
backend slice is the control-plane read model and evaluator that makes those
choices usable without moving compatibility logic into Flutter shells.

Shells should not infer whether VK TURN plus WireGuard, SFU plus SOCKS5, or a
future Telemost plus Hysteria combination is valid. The host must report
candidate runtime plans, selected source/profile status, and fail-closed
reasons through a typed API.

## Sequence

- Order: `78`
- Depends on: `add-77-independent-provider-and-transport-selection`,
  accepted VPN transport profile store contracts, and current
  runtime-execution-planning contracts
- Unblocks: backend-first implementation of the provider/source plus VPN
  transport profile selector before desktop/mobile UI polish

## What Changes

- Add a provider/transport compatibility control-plane surface that reports
  plan candidates for a selected provider source or resolved artifact and a
  selected VPN transport profile.
- Define a server-side compatibility evaluator over source/artifact state,
  access method, carrier family, engine family, host adapter, required profile
  kind, selected profile reference, support state, degraded state, and evidence
  state.
- Require startup requests to carry explicit source/resolution/artifact and
  transport-profile references when both axes are needed.
- Return typed failing-axis and reason metadata instead of making shells infer
  why a combination is blocked.
- Keep the first implementation backend-only: no new provider contour, no new
  VPN engine, and no UI redesign in this change.

## Impact

- Affected specs: `provider-transport-compatibility-control-plane` (new),
  `client-control-plane`, `runtime-execution-planning`,
  `provider-runtime-artifacts`, `vpn-transport-profile-store`
- Affected code: future `pkg/clientcontrol` DTOs and HTTP handlers,
  compatibility evaluator, platform-tunnel startup validation, host-info
  capability metadata, and Go tests

## Assumptions

- The first implementation can evaluate existing VK/Generic TURN and
  `wireguard_native_v1` combinations before adding new contours or engines.
- Existing explicit transport-profile selection remains authoritative; the
  evaluator must not reintroduce most-recent compatible profile selection.
- Provider resolution expiry and profile validation are runtime facts that can
  change between read-model evaluation and startup, so startup must revalidate.
