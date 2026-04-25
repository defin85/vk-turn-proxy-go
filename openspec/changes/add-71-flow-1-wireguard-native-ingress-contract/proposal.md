# Change: Define WireGuard-native remote ingress contract

## Why

Live Windows VM validation exposed a contract mismatch: the desktop
`windows_wintun` strict `turn_datagram + wireguard_native` path can report
session readiness while raw WireGuard datagrams are sent to the VPS DTLS overlay
port. The existing `56040/udp` listener is a DTLS/custom-overlay endpoint; it
cannot implicitly accept raw WireGuard datagrams just because it can serve
multiple clients.

A temporary plain listener on `56042/udp` forwarding to the WireGuard UDP
endpoint made the same Windows VM data plane work end-to-end. The repository
needs to encode that distinction before turning the lab setup into product
behavior.

## What Changes

- Define the remote UDP ingress contract for strict `wireguard_native` as
  protocol-specific: either a dedicated raw-WireGuard/plain listener or an
  explicit UDP protocol multiplexer.
- Require runtime execution planning to materialize a `wireguard_native` remote
  ingress separately from the DTLS overlay endpoint used by
  `turn_dtls_overlay + custom_packet_overlay`.
- Document that one UDP port may serve many clients for the same protocol or a
  proven demux contract, but not mixed DTLS overlay and raw WireGuard traffic by
  assumption.
- Add implementation tasks for the VPS service/runbook, Windows host defaults,
  fail-closed validation, and live VM/VPS verification.

## Impact

- Affected specs: `wireguard-turn-carrier`, `runtime-execution-planning`
- Affected code: `internal/windowsdesktophost`,
  `internal/wireguardturnruntime`, `pkg/clientcontrol`, runtime-default
  materialization, VPS service/runbook scripts, Windows VM smoke scripts
- Deployment impact: likely requires either a persistent plain UDP ingress
  (validated in the lab as `56042/udp`) or a later explicit UDP demultiplexer on
  the existing external port
