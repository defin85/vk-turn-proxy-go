## Context

The current repository already has the important building blocks:

- provider descriptors and resolved runtime artifacts
- typed runtime execution plans
- host-owned VPN transport profile store
- desktop and mobile VPN transport profile managers
- multitransport pathset planning

The missing product contract is the operator mental model: provider contours
and VPN transport profiles are separate catalogs. If the UI or control plane
mixes them into one profile, RelayDock will drift back toward hard-coded
pairings such as "VK TURN equals WireGuard" or "one provider profile owns one
transport secret".

## Goals

- Make provider-source selection and VPN transport-profile selection separate
  user workflows.
- Let startup combine those choices only through the typed compatibility
  matrix.
- Keep each axis independently extensible: new provider contours do not require
  new VPN profile UI, and new VPN transports do not require provider-specific
  UI rewrites.
- Preserve fail-closed startup behavior for unsupported combinations.

## Non-Goals

- Implement new providers such as WB TURN, Telemost, SFU, or Rostelecom video
  in this change.
- Implement new VPN transport engines such as V2Ray, SOCKS5, Hysteria, or QUIC
  in this change.
- Claim that every provider contour can run with every VPN transport profile.
- Move primary VPN start/stop ownership away from the existing Home workflow.

## Decisions

### Decision: Provider sources and VPN transport profiles are two axes

The product UI should expose an external source catalog and a VPN transport
profile catalog as separate workspaces. A source can resolve or attach to a
provider contour; a VPN transport profile supplies local engine material for a
compatible runtime plan.

### Decision: Compatibility is computed, not implied by selection

Selecting one provider source and one VPN transport profile does not itself
make startup valid. The host must evaluate the resolved provider artifact,
carrier family, engine family, host adapter, required profile kind, and selected
profile reference before enabling startup.

### Decision: Records do not smuggle the other axis

Provider records may store reusable provider-owned settings and provider
source intent. VPN transport profiles may store local engine material and
transport-profile lifecycle state. Neither record type owns the other axis'
secrets or hidden defaults.

### Decision: Unsupported combinations remain inspectable

Operators should be able to see that a desired combination is unsupported,
degraded, setup-needed, or missing evidence. The shell must not silently choose
a different provider source, carrier, engine, or VPN transport profile to make
the UI look ready.
