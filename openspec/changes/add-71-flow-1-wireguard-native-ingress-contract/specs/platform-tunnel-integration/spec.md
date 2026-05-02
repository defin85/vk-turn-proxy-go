## ADDED Requirements

### Requirement: Platform tunnel readiness exposes remote ingress diagnostics

The platform tunnel startup/status contract SHALL expose the selected remote
ingress protocol, address, and isolation for strict
`turn_datagram + wireguard_native` readiness.

#### Scenario: Ready strict WireGuard result names raw ingress

- **GIVEN** a packaged platform tunnel host reaches `ready=true` for a strict
  `turn_datagram + wireguard_native` plan
- **WHEN** the host returns the startup result or current platform tunnel status
- **THEN** `remote_ingress.protocol` is `raw_wireguard_datagram` or a verified
  UDP protocol multiplexer
- **AND** `remote_ingress.address` names the selected ingress address
- **AND** `remote_ingress.isolation` identifies whether the endpoint is
  dedicated or mux-backed
- **AND** the shell can display those diagnostics without exposing WireGuard
  secret material
