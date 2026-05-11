## Context

The repository already has the core strict WireGuard carrier pieces:

- typed execution planning for `turn_credentials + turn_datagram +
  wireguard_native + linux_tun`
- transport-profile store and host-owned lease materialization
- userspace WireGuard-over-TURN runtime with Linux TUN-device support

What Linux still lacks is a packaged host lifecycle that turns those pieces into
one concrete Ubuntu desktop startup path with typed stage results and
cleanup semantics.

## Goals

- Define one concrete Ubuntu-first `linux_tun` lifecycle under the packaged
  desktop host boundary.
- Reuse the canonical `/v1/platform-tunnels/start` control-plane API and
  existing strict WireGuard lease materialization.
- Keep the route policy explicit and fail-closed.
- Require Linux dataplane evidence before readiness.

## Non-Goals

- Broad cross-distro support claims.
- Replacing the strict TURN-backed `wireguard_native` carrier with a different
  engine family.
- Defining the final installer or package promotion surface.

## Decisions

### Decision: The first Linux runtime slice is Ubuntu-first

The ready path should target the Ubuntu desktop contour that already exists in
the lab instead of attempting to generalize across every Linux distro, init
stack, and privilege mediation surface in one change.

### Decision: The first Linux route policy is `preserve_active_local_network`

Like the verified Windows path, the first Linux runtime slice should start with
`preserve_active_local_network` rather than claiming all possible route-policy
shapes immediately. This keeps control-traffic preservation explicit and
reduces the chance of overclaiming support too early.

### Decision: Strict WireGuard runtime attach stays host-owned

The Linux host continues to materialize the strict execution lease and then
attaches the existing userspace WireGuard TURN runtime under the packaged host
boundary. The helper may own native TUN or route work, but it does not replace
the control-plane orchestration or provider/materialization flow.

### Decision: Linux readiness needs typed dataplane evidence

`ready=true` for `linux_tun` should require the same class of evidence already
required for the verified packaged paths:

- host-attached runtime
- fresh WireGuard handshake
- positive WireGuard traffic deltas
- verified remote egress over the expected path

### Decision: Cleanup remains mandatory after host bring-up or runtime attach

If Linux startup fails after partial host bring-up, route policy application, or
runtime attach, the packaged host must tear down partial native state before it
returns failure.

## Risks / Trade-offs

- Ubuntu-specific assumptions may not hold on other distros.
- Linux route-policy mistakes can cut off control traffic or leave stale rules.
- Host/helper crash behavior must be designed carefully so cleanup is reliable.

## Validation Plan

- Host and control-plane tests for Linux stage-aware startup semantics.
- Ubuntu VM validation for TUN, route policy, runtime attach, cleanup, and
  dataplane proof.
- Strict OpenSpec validation for this change.
