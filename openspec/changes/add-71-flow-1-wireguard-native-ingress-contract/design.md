## Context

The current VPS production listener on `56040/udp` runs `tunnel-server` in
`peer-mode dtls` and forwards the custom overlay path. During live Windows VM
testing, `windows_wintun` sent raw WireGuard packets through TURN to that DTLS
endpoint. TURN delivery worked, but the server did not answer because the first
byte stream was the wrong protocol for that listener.

The same VM and WireGuard profile worked after opening `56042/udp` and running a
temporary `tunnel-server` in `peer-mode plain` connected to the WireGuard UDP
endpoint. Evidence included a fresh WireGuard handshake, Wintun received bytes,
bidirectional server counters, and `api.ipify.org` returning the VPS IP.

## Goals / Non-Goals

- Goals:
  - Keep the mobile/custom-overlay DTLS path on its existing DTLS ingress.
  - Define the strict `turn_datagram + wireguard_native` remote ingress as a
    separate protocol contract.
  - Make the host fail closed when a strict WireGuard plan points at a
    DTLS-only endpoint without an explicit multiplexer.
  - Keep multi-client support honest: many clients are allowed on one listener
    only when they share the listener protocol or the demux contract is real.
- Non-Goals:
  - Do not replace the mobile DTLS/custom-overlay runtime.
  - Do not claim one-port mixed-protocol support until a multiplexer is designed,
    implemented, and verified.
  - Do not treat local attach success as proof of remote data-plane success.

## Decisions

### Decision: The first fix should prefer a dedicated plain WireGuard ingress

A dedicated raw-WireGuard/plain ingress is the smallest contract that matches the
successful lab evidence. It keeps the existing DTLS listener untouched and makes
the runtime endpoint selection visible in configuration, diagnostics, and
deployment docs.

### Decision: A shared external port requires an explicit UDP demultiplexer

Using one external UDP port for both DTLS overlay and raw WireGuard is possible
only if the server owns a demux contract that can classify initial packets,
route sessions, preserve reply routing, and expose metrics/errors per protocol.
Until that exists, sharing `56040/udp` would hide a protocol mismatch behind a
single address.

### Decision: Android WireGuard material is explicit runtime state

The earlier phone/tablet evidence used a workstation-local WireGuard profile as
PoC input. That file is not an application configuration contract. No Android
debug, MCP, release, or Play build may package or auto-stage `phone1.conf`, and
the embedded host must not read a WireGuard profile from environment defaults.

Android `android_vpn_service` may advertise the strict
`turn_datagram + wireguard_native` execution path only when the app has an
operator-imported app-owned WireGuard profile and the host can materialize a
lease from that explicit path. The mobile GUI owns the import/replace/forget
surface; ordinary shell state may remember only status metadata, not raw private
keys.

## Alternatives Considered

- Switch `56040/udp` from DTLS to plain. Rejected because it breaks the existing
  DTLS/custom-overlay path.
- Keep sending raw WireGuard to `56040/udp`. Rejected because live evidence
  showed TURN delivery without remote protocol acceptance.
- Build a UDP multiplexer immediately. Viable later, but higher risk than a
  dedicated ingress because it changes the production listener boundary and
  needs protocol-classification tests.

## Risks / Trade-offs

- A second UDP port adds VPS/provider firewall and service-management work.
- A future one-port design must avoid ambiguous protocol sniffing and must not
  regress DTLS clients.
- Windows UI readiness can still be misleading unless verification distinguishes
  host attach, WireGuard handshake, and bidirectional traffic.
- Android UI readiness can also be misleading unless missing WireGuard material
  is surfaced as a setup action instead of a hidden file prerequisite.

## Migration Plan

1. Add a persistent VPS-side raw-WireGuard ingress or explicitly approve a UDP
   multiplexer design.
2. Update strict `wireguard_native` planning/materialization to select that
   ingress instead of the DTLS overlay peer address.
3. Add fail-closed validation and diagnostics when the selected endpoint is not
   a strict WireGuard ingress.
4. Verify Windows VM data-plane success and confirm the existing DTLS overlay
   path still targets the DTLS listener.
5. Remove Android packaged WireGuard seed paths and add an explicit app-owned
   runtime profile surface before claiming Android strict WireGuard support.

## Open Questions

- Should the first productized contour reserve `56042/udp` as the canonical
  raw-WireGuard ingress, or should the final port be configured per deployment?
- Do we need one external port for operator simplicity, or is a separate
  protocol-specific port acceptable for the first supported Windows VPN path?
- Should the Android UI import a full WireGuard `.conf` first, or should a later
  flow generate/import only the minimal key/address fields through typed form
  controls?
