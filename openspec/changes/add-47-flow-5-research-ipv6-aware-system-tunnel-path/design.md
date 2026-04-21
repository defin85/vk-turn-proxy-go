## Context

The repository's first packaged system-tunnel path is intentionally narrow:
`turn_datagram + wireguard_native`.
That path is already explicit in runtime planning, platform-tunnel integration,
and carrier specs, but the current host and PoC evidence are IPv4-centric.

Today that means the repository can reach a truthful "ready runtime" state for
an IPv4 path without having a truthful dual-stack privacy claim.
If a host still has active IPv6 connectivity and the packaged tunnel path does
not capture or exclude IPv6 safely, an operator can observe a mismatch between
the reported VPN-ready state and the actual egress path for IPv6-capable
traffic.

This follow-up exists to separate those concerns explicitly before the
repository overclaims full-tunnel semantics on dual-stack networks.

## Goals

- Make packaged system-tunnel support claims address-family-scoped instead of
  treating IPv4 readiness as implicit dual-stack coverage
- Define when a packaged `turn_datagram + wireguard_native` path may truthfully
  claim dual-stack coverage
- Keep route preparation and underlay exclusion handling family-aware and
  fail-closed on dual-stack hosts
- Expose typed coverage or limitation metadata through the local control plane
  so shells do not infer dual-stack support from `ready=true` alone
- Require repo-owned dual-stack verification before shipping an IPv6-aware
  support claim

## Non-Goals

- Declaring the current overlay runtime to be dual-stack-equivalent to a
  packaged system tunnel
- Introducing a new carrier or engine family beyond the existing
  `turn_datagram + wireguard_native` path
- Solving every IPv6 edge case such as NAT64, DNS64, or roaming heuristics in
  the same change
- Treating external WireGuard tooling or generic OS VPN behavior as equivalent
  proof for the repo-owned packaged path

## Decisions

### Decision: Full-tunnel claims become address-family-scoped

A packaged system-tunnel support claim now needs two layers:

- the runtime path is startable and may reach `ready=true`
- the host advertises which traffic families that path actually covers

That keeps the repository honest when an IPv4 path works but IPv6 is still
outside the documented packaged tunnel semantics.

### Decision: Dual-stack support stays narrow to the packaged WireGuard path

This follow-up does not broaden the execution-family matrix.
It only extends the documented packaged `turn_datagram + wireguard_native`
system-tunnel path so that Android and desktop hosts can later claim dual-stack
coverage truthfully.

### Decision: Family-complete carrier state stays host-owned

If a packaged host later claims IPv6-aware support, the host-owned execution
lease must carry the necessary dual-stack carrier state internally: client
addresses, allowed IPs, DNS data, peer data, and route-exclusion inputs for the
families it claims to support.
Ordinary reads still expose typed planning and status data, not raw secret
material.

### Decision: Dual-stack readiness is fail-closed on active IPv6 underlays

If the active underlay exposes IPv6 connectivity and the requested packaged
mode cannot safely prepare or preserve the documented IPv6 path, startup must
fail before `ready=true` for a dual-stack support claim.
The repository should not silently degrade to IPv4-only behavior while still
presenting the result as a complete system tunnel.

### Decision: Shells consume typed coverage metadata instead of guessing

Shells need typed metadata for address-family coverage or limitation state.
They should not reverse-engineer dual-stack support from localized text,
implementation-specific warnings, or provider documentation.

## Risks / Trade-offs

- IPv6 route preparation and exclusion behavior differ more across operating
  systems than the current IPv4 split-route pattern
- The local control-plane contract gets wider, but that is preferable to
  overloading `ready=true` with semantics it does not actually prove
- Dual-stack verification is more expensive because it needs real IPv4 and IPv6
  egress evidence instead of one generic public-IP check
- If this work is underspecified, shells may still present an IPv4-only path as
  if it were a complete privacy tunnel

## Validation Plan

- Add spec deltas for runtime planning, platform-tunnel integration,
  client-control-plane coverage metadata, and the strict WireGuard carrier
  contract
- Keep the proposal explicit that the current packaged path is not a truthful
  dual-stack claim until IPv6-specific route, lease, and evidence work exists
- Require repo-owned evidence for:
  - IPv4-only startup remaining explicit instead of masquerading as dual-stack
  - dual-stack host startup failing closed when IPv6 route preparation or
    exclusion handling is incomplete
  - real dual-stack egress verification, for example distinct IPv4 and IPv6
    probes showing the documented VPS path
- `openspec validate add-47-flow-5-research-ipv6-aware-system-tunnel-path --strict --no-interactive`
