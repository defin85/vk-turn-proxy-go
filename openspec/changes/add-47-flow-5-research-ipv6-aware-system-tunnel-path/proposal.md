# Change: [47] Add IPv6-aware packaged system-tunnel path

## Why

Current packaged system-tunnel work and Windows WireGuard PoCs are explicitly
IPv4-centric.
The documented split routes, underlay exclusions, and current ready-path host
logic all operate on IPv4-only primitives.
That keeps the current work honest for IPv4 smoke, but it does not support a
truthful dual-stack privacy or "all traffic exits through the VPS" claim on
hosts that also have active IPv6 connectivity.

The repository needs a separate follow-up that defines when packaged Android
and desktop system-tunnel support may truthfully claim full dual-stack coverage
instead of treating an IPv4-ready path as equivalent.

## Sequence

- Order: `47`
- Depends on: `add-22-runtime-execution-planning`,
  `add-23-turn-datagram-wireguard-carrier`,
  `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`,
  `add-26-android-vpnservice-host-boundary`,
  `add-33-android-dev-wifi-routing-profile`
- Unblocks: honest dual-stack system-tunnel claims for future packaged Android
  and desktop hosts without overstating the current IPv4-only ready paths

## What Changes

- Add explicit address-family coverage semantics for packaged
  `turn_datagram + wireguard_native` system-tunnel plans so hosts can report
  whether a mode is IPv4-only or dual-stack capable.
- Extend platform-tunnel startup so dual-stack readiness requires IPv6-aware
  route preparation, exclusion handling, and fail-closed validation on hosts
  that expose active IPv6 connectivity.
- Extend the local control plane so shells can distinguish "ready runtime" from
  "complete dual-stack system-tunnel coverage" instead of inferring that from
  `ready=true` or unstructured message text.
- Extend the strict WireGuard carrier contract so a packaged host may claim
  dual-stack support only when its host-owned execution lease and route policy
  cover both IPv4 and IPv6 without leaking secret-bearing carrier state.
- Require repo-owned dual-stack verification before any packaged Android or
  desktop host claims IPv6-aware system-tunnel support.

## Impact

- Affected specs: `runtime-execution-planning`,
  `platform-tunnel-integration`, `client-control-plane`,
  `wireguard-turn-carrier`
- Affected code: `pkg/clientcontrol`, packaged Android and desktop
  platform-tunnel hosts, WireGuard materializers, runtime diagnostics, shell
  consumers of host capability and startup metadata, and dual-stack validation
  runbooks
