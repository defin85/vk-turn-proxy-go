# Runtime Execution Planning

This repository keeps provider resolution separate from host-owned same-device execution.
Provider resolution answers "what artifact did we get?".
Runtime execution planning answers "how can this host consume that artifact on this device?".

## Current documented execution edges

The compatibility matrix is explicit and fail-closed.
The host must not infer support from provider identifiers, platform names, or one successful path on another adapter.

### Supported current same-device runtime

- `access_method`: `turn_credentials`
- `carrier_family`: `turn_dtls_overlay`
- `engine_family`: `custom_packet_overlay`
- `host_adapter`: none
- `remote_endpoint_family`: `turn_server`
- `support_state`: `supported`

This is the current repo-owned same-device runtime path behind `Start on this device`.
It remains distinct from packaged system-tunnel work.

### Documented packaged system-tunnel planning contract

- `access_method`: `turn_credentials`
- `carrier_family`: `turn_datagram`
- `engine_family`: `wireguard_native`
- `host_adapter`: one of `android_vpn_service`, `windows_wintun`, `linux_tun`, or `apple_network_extension`
- `remote_endpoint_family`: `turn_server`
- `support_state`: adapter-specific and fail-closed

Current support claims are:

- `android_vpn_service`: supported on the documented packaged Android target
- `windows_wintun`: supported on the documented packaged Windows target through the bundled host-owned Wintun lifecycle when the strict local WireGuard materializer prerequisite is present
- `linux_tun`, `apple_network_extension`: still unavailable until those packaged hosts ship the adapter path

Hosts must keep every adapter-specific claim honest.
The planning contract says which packaged path is in scope; it does not authorize future adapters to report support early.

## Strict TURN-datagram WireGuard carrier boundary

- The host now treats the strict TURN-backed `wireguard_native` path as a
  separate internal carrier/materialization boundary instead of as a synonym
  for the current DTLS overlay runtime.
- Ordinary resolution reads may advertise the strict planning tuple, but they do
  not expose a startable carrier lease or raw WireGuard material.
- A strict carrier lease stays host-owned and secret-bearing. Private keys,
  peer keys, and carrier-secret material must not appear in ordinary reads,
  events, diagnostics, or persisted shell state.
- Packaged `wireguard_native` mode reports are fail-closed: a host adapter is
  not enough on its own. If the strict carrier/materializer is absent, packaged
  host modes must keep that execution plan unavailable.
- The explicit remote role for this path remains under the `turn_server`
  endpoint family, but it is a distinct WireGuard-over-TURN datagram role, not
  proof that the current DTLS overlay server already satisfies the packaged
  path.

## Evidence bar for support claims

Support claims for the strict TURN-backed `wireguard_native` path need repo-owned
evidence for all of the following:

- host-owned lease materialization without leaking raw WireGuard or carrier
  secrets through ordinary shell-facing state
- fail-closed startup when the carrier/materializer or remote role is missing
- explicit carrier truth rather than inferred DTLS overlay compatibility
- real WireGuard payload traffic over the strict `turn_datagram` path

Current repo-owned evidence now covers:

- the first packaged Android path through `android_vpn_service`, including
  typed `ready=true` startup on the supported device target for:

  - `all_apps`
  - `allowed_packages`
- the first packaged Windows path through `windows_wintun`, including
  repo-owned `ready=true` startup on the supported packaged target and
  host-owned route or DNS preparation plus teardown in the bundled host

## Remote endpoint ownership

- TURN-backed carriers keep using the current `turn_server` family.
- Future `webrtc_datachannel` plans must name a different remote endpoint family such as `webrtc_call_endpoint`.
- Future HTTPS-like tunnel plans must name their own remote endpoint family such as `https_tunnel_server`.
- When a plan declares a packaged `host_adapter`, packet capture, route control, and DNS-bypass ownership stay inside that adapter boundary instead of leaking into provider logic or remote endpoint roles.

The current `turn-server` role is not a universal backend for all future execution families.

## Experimental and foreign-core gating

- `webrtc_datachannel` remains experimental and non-default.
- Any `webrtc_datachannel` plan must stay behind the capability `runtime_execution_experimental_webrtc_datachannel`.
- Foreign-core engine families such as `proxy_core_adapter` or `trusttunnel_native` must stay behind the capability `runtime_execution_foreign_core`.
- This repository does not currently advertise supported startup for those experimental or foreign-core plans.

## Follow-on slices

1. `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`: shipped the first desktop packaged host path that turns the documented TURN-backed `wireguard_native` plan into a real Windows desktop adapter ready path.
3. Experimental `webrtc_datachannel`: define a real remote endpoint, framing, and lifecycle verification path before any host advertises it as startable.
4. Foreign-core engines: add packaging, lifecycle ownership, and verification evidence before any host advertises `proxy_core_adapter` or `trusttunnel_native` as startable.

Android and desktop follow-on work must consume this prerequisite carrier
boundary instead of replacing it with the current
`turn_dtls_overlay + custom_packet_overlay` runtime or with external WireGuard
compatibility workflows.
