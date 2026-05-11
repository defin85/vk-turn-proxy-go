# Change: [84] Add `linux_tun` Ubuntu ready path

## Why
After `add-83-flow-10-linux-tun-host-boundary`, the repository can describe how
Linux packaged hosts own native tunnel privilege, but it still lacks the actual
`linux_tun` runtime path: TUN bring-up, route policy, strict TURN-backed
WireGuard runtime attach, dataplane verification, and cleanup semantics.

The first concrete Linux delivery should stay narrow and target the current
Ubuntu desktop contour already available in the lab, instead of pretending to
cover every Linux distro at once.

## Sequence
- Order: `84`
- Flow: `10`
- Depends on: `add-83-flow-10-linux-tun-host-boundary`,
  `add-23-turn-datagram-wireguard-carrier`,
  `add-73-vpn-transport-profile-store`
- Unblocks: `add-85-flow-10-linux-tun-packaging-support-promotion`

## What Changes
- Define the first concrete `linux_tun` startup lifecycle for the documented
  Ubuntu desktop target.
- Define Ubuntu-first route policy for `linux_tun`, including
  `preserve_active_local_network` and explicit fail-closed control-traffic
  preservation.
- Define strict TURN-backed `wireguard_native` runtime attach for the Linux
  host/helper path using the existing userspace WireGuard TURN runtime.
- Define typed startup failure, dataplane verification, and cleanup semantics
  for Linux bring-up.
- Keep the support claim promotion separate. This change defines the ready path
  mechanics and verification bar; later packaging/promotion work decides when
  the packaged build may advertise it as supported by default.

## Impact
- Affected specs: `desktop-sidecar-host`, `platform-tunnel-integration`,
  `client-control-plane`
- Affected code: future `internal/linuxdesktophost`, Linux helper/runtime
  integration, `cmd/clientd` Linux wiring, Ubuntu VM smoke coverage
