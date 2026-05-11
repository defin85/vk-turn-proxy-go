## ADDED Requirements
### Requirement: Packaged Linux desktop hosts own the first concrete `linux_tun` runtime lifecycle

Packaged Linux desktop hosts SHALL own the first concrete `linux_tun` runtime
lifecycle for the documented Ubuntu desktop target.

#### Scenario: Linux host reaches runtime attach through the packaged host boundary

- **GIVEN** a packaged Linux desktop host that satisfies the documented
  `linux_tun` prerequisites for the supported Ubuntu target
- **WHEN** the operator starts the packaged desktop system-tunnel workflow
- **THEN** the packaged host owns Linux TUN bring-up, route policy
  preparation, runtime attach, and teardown for that mode
- **AND** the operator does not need an external WireGuard GUI or manual route
  commands to reach the typed startup result
