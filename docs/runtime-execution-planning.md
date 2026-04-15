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
- `support_state`: currently `unavailable` until the packaged host actually ships that adapter path

Current desktop and mobile hosts may report these documented `wireguard_native` plans as unavailable for their target mode.
That is intentional: the contract says which packaged path is in scope, not that it already works.

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

1. `add-17-android-vpn-service-ready-path`: ship one Android packaged host path that turns the documented TURN-backed `wireguard_native` plan into a real `android_vpn_service` ready path.
2. `add-18-desktop-platform-tunnel-ready-paths`: ship one desktop packaged host path that turns the documented TURN-backed `wireguard_native` plan into a real desktop adapter ready path.
3. Experimental `webrtc_datachannel`: define a real remote endpoint, framing, and lifecycle verification path before any host advertises it as startable.
4. Foreign-core engines: add packaging, lifecycle ownership, and verification evidence before any host advertises `proxy_core_adapter` or `trusttunnel_native` as startable.
