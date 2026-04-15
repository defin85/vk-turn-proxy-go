# Change: [24] Add experimental WebRTC datachannel runtime path

## Why
`add-22-runtime-execution-planning` intentionally left room for execution
families beyond the TURN-backed `wireguard_native` path.
That made the contract extensible, but it did not define a real repo-owned
non-WireGuard carrier that can move host-owned traffic.

Today the repository has:

- the current repo-owned same-device runtime through
  `turn_dtls_overlay + custom_packet_overlay`
- the strict future packaged system-tunnel target through
  `turn_datagram + wireguard_native`
- placeholder planning metadata for experimental `webrtc_datachannel`

What is still missing is one concrete future change that proves the repository
can carry runtime traffic through a non-WireGuard carrier without overloading
that work onto packaged VPN changes or foreign-core adapters.

## Sequence
- Order: `24`
- Depends on: `add-20-multi-provider-runtime-families`, `add-22-runtime-execution-planning`
- Unblocks: a first repo-owned non-WireGuard execution family for future mobile and desktop shells without redefining packaged VPN scope

## What Changes
- Add a new `webrtc-datachannel-carrier` capability spec for the first
  repo-owned non-WireGuard same-device execution path.
- Define that path narrowly as:
  `access_method=webrtc_call_attach`,
  `carrier_family=webrtc_datachannel`,
  `engine_family=custom_packet_overlay`,
  `remote_endpoint_family=webrtc_call_endpoint`.
- Define which resolved artifacts may advertise that attach path and how hosts
  materialize the attach state without leaking secret-bearing room or attach
  details through ordinary shell-facing reads.
- Extend the client control plane so shells can negotiate, request, and fail
  closed on the experimental WebRTC datachannel path explicitly.
- Require repo-owned evidence for real payload traffic over the datachannel path
  before any host may advertise it as a supported default execution plan.

## Impact
- Affected specs: `webrtc-datachannel-carrier` (new), `provider-runtime-artifacts`, `client-control-plane`
- Affected code: future provider artifact modeling for attachable room surfaces, `pkg/clientcontrol`, future WebRTC attach/runtime packages, desktop/mobile shell consumers, and repo-owned verification/docs evidence
