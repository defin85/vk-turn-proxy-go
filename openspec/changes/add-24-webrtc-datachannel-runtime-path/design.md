## Context

`add-22-runtime-execution-planning` split same-device execution into typed
fields such as `access_method`, `carrier_family`, `engine_family`, and remote
endpoint ownership.
That change already reserved room for a non-TURN `webrtc_datachannel` carrier,
but only as an experimental, capability-gated planning concept.

The repository therefore still lacks one concrete future slice that answers:

- which artifacts may expose a repo-owned WebRTC attach path
- what local engine should consume that path first
- where the secret-bearing attach state lives
- what "ready" means for a non-WireGuard, non-system-tunnel execution family

## Goals

- Define the first concrete repo-owned non-WireGuard execution path
- Keep that path explicit as
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay`
- Keep the remote endpoint ownership explicit as `webrtc_call_endpoint`
- Preserve fail-closed behavior when attach targets, capabilities, or channel
  bring-up are missing
- Keep shells as typed consumers rather than owners of attach/session secrets

## Non-Goals

- Delivering packaged Android or desktop VPN support
- Reinterpreting TURN-backed `wireguard_native` work as if it covered WebRTC
- Introducing foreign-core engines such as `proxy_core_adapter` or
  `trusttunnel_native`
- Claiming that any conference-style artifact automatically supports
  repo-owned WebRTC traffic execution
- Defining a generic umbrella for every future non-WireGuard carrier family

## Decisions

### Decision: The first non-WireGuard path uses `custom_packet_overlay`

The repository already owns `custom_packet_overlay` as a local execution
engine.
For the first non-WireGuard carrier slice, pairing it with
`webrtc_datachannel` is narrower and more realistic than introducing a new
engine family at the same time.

### Decision: Artifact eligibility comes from attachable room surfaces, not TURN

This path should start from artifacts that can truthfully advertise
`webrtc_call_attach`.
It must not be synthesized from `generic_turn` or from ordinary room-open
actions that do not produce a repo-owned attach/runtime contract.

### Decision: Attach material stays host-owned and redacted

Starting a repo-owned datachannel path may require room-scoped tokens, call
identifiers, peer/session offers, or similar secret-bearing attach state.
That state should be materialized and consumed inside the host boundary.
Ordinary control-plane reads should expose typed plan and status data, not raw
attach blobs.

### Decision: `webrtc_call_endpoint` is a real remote runtime role

The remote endpoint for this path is not the current `turn_server`.
This change therefore keeps `webrtc_call_endpoint` explicit and requires real
carrier/runtime evidence against that endpoint family before any host may claim
supported startup.

### Decision: The path remains experimental and non-default until verified

Even after the contract exists, hosts should not auto-select this path as a
default same-device runtime.
It stays capability-gated and fail-closed until the repository proves a
repo-owned attach lifecycle plus real traffic over the datachannel carrier.

## Risks / Trade-offs

- Conference-style provider flows may vary, so the attach contract can become
  too provider-specific if it is not kept narrow
- If attach/session material is underspecified, shells or diagnostics may leak
  room-scoped secrets
- A fake "channel connected" signal could be misread as traffic readiness if
  the evidence bar is not strict
- This change can sprawl into generic conferencing abstractions if it stops
  being anchored to one repo-owned execution path

## Validation Plan

- Add a new `webrtc-datachannel-carrier` capability spec plus deltas for
  provider-runtime artifacts and the client control plane
- Keep the proposal narrow to one explicit execution tuple instead of a generic
  non-WireGuard umbrella
- Require repo-owned evidence for:
  - host-owned attach materialization without secret leakage
  - fail-closed startup when the attach target, capability, or channel bring-up
    is missing
  - real payload traffic over the `webrtc_datachannel` path
- Leave foreign-core and HTTPS-like carrier families to future changes
- `openspec validate add-24-webrtc-datachannel-runtime-path --strict --no-interactive`
