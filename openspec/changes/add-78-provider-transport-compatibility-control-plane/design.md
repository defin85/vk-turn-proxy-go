## Context

RelayDock already has typed runtime execution plans and a host-owned VPN
transport profile store. `add-77` adds the product-level separation between
provider sources and VPN transport profiles.

The missing backend piece is a single host-owned compatibility evaluator that
answers:

- which provider/source or resolved artifact is being considered
- which VPN transport profile is selected or required
- which runtime execution plan would connect them
- whether the current combination is startable, setup-needed, unsupported,
  degraded, missing evidence, or stale
- which axis is responsible for a blocked state

Without that server read model, desktop and mobile shells will duplicate
compatibility heuristics and drift from the fail-closed control-plane contract.

## Goals

- Add a versioned control-plane surface for provider/transport compatibility
  candidates.
- Keep compatibility evaluation host-owned and deterministic.
- Make failing-axis reasons explicit and shell-consumable.
- Reuse existing runtime execution plan and transport profile models instead of
  inventing a parallel UI-only compatibility schema.
- Revalidate the exact selected combination during startup.

## Non-Goals

- Implement SFU, Telemost, WB TURN, Rostelecom, V2Ray, SOCKS5, Hysteria, or
  QUIC transport support.
- Change the existing VPN transport profile storage format.
- Move provider resolution, profile validation, or native adapter work into the
  Flutter shell.
- Archive or complete `add-77`.

## Decisions

### Decision: Compatibility is a host read model plus startup guard

The host should expose compatibility candidates for UI planning, but startup
must re-run validation because provider resolutions can expire and profiles can
be edited, forgotten, or invalidated between reads.

### Decision: Candidate identity is typed, not display-only

Each candidate must carry stable machine-readable source, artifact, execution
plan, and transport-profile references where available. Display labels are
secondary and must not be the only way to request startup.

### Decision: Failing axis is explicit

Blocked combinations should identify whether the provider/source,
artifact/access method, carrier, engine, host adapter, transport profile,
evidence, degraded policy, or host capability is responsible. This lets shells
link to the right setup surface without guessing.

### Decision: No implicit rescue selection

The evaluator must not choose a different provider source or the last
compatible transport profile to make a candidate startable. It may report
available alternatives, but the selected combination remains explicit.
