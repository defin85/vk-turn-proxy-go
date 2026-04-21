# Change: [23] Add TURN datagram WireGuard carrier prerequisite

## Why
`add-22-runtime-execution-planning` intentionally locked the first packaged
system-tunnel path to a TURN-backed `wireguard_native` execution plan with
`carrier_family=turn_datagram`.
That made the target honest, but it did not create the carrier itself.

Today the repository proves only two adjacent but different paths:

- the current repo-owned same-device runtime through
  `turn_dtls_overlay + custom_packet_overlay`
- external WireGuard clients running above the current repo-owned transport slice

Those proofs do not produce a repo-owned, startable `turn_datagram`
`wireguard_native` carrier.
Without an explicit prerequisite change, `add-17` and `add-18` will either
overload Android or desktop adapter work with a missing carrier/backend problem,
or silently drift away from the strict `add-22` contract.

## Sequence
- Order: `23`
- Depends on: `add-05-platform-tunnel-integrations`, `add-20-multi-provider-runtime-families`, `add-22-runtime-execution-planning`
- Unblocks: strict `add-17-android-vpn-service-ready-path` and `add-18-flow-1-desktop-core-platform-tunnel-ready-paths` delivery under the documented TURN-backed `wireguard_native` plan

## What Changes
- Add a new `wireguard-turn-carrier` capability spec that defines the
  repo-owned carrier and execution-materialization layer required for strict
  `turn_datagram + wireguard_native` startup.
- Define a host-owned, secret-bearing WireGuard execution lease that can be
  materialized from a resolved `generic_turn` artifact without leaking raw
  WireGuard or carrier secrets into ordinary shell-facing reads.
- Define the TURN-backed datagram carrier contract separately from the current
  `turn_dtls_overlay + custom_packet_overlay` runtime so one path does not
  masquerade as the other.
- Define the remote `turn_server` role for WireGuard-over-TURN datagram
  termination explicitly instead of implying that the current DTLS overlay
  server already satisfies that role.
- Extend provider/runtime artifact and control-plane requirements so hosts may
  materialize and consume strict `wireguard_native` carrier state internally
  while still failing closed when the materializer or carrier is absent.

## Impact
- Affected specs: `wireguard-turn-carrier` (new), `provider-runtime-artifacts`, `client-control-plane`, `platform-tunnel-integration`
- Affected code: future `internal/provider` artifact materialization, `pkg/clientcontrol`, future TURN-datagram WireGuard carrier/runtime packages, remote `turn_server` WG termination, packaged host integrations, and repo-owned e2e/docs evidence
