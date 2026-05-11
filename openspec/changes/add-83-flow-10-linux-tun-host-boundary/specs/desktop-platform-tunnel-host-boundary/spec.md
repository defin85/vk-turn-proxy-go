## ADDED Requirements
### Requirement: Packaged Linux desktop hosts may use a privileged helper without splitting the desktop host boundary

The system SHALL allow a packaged Linux desktop host to reach `linux_tun`
through a repo-owned privileged helper while preserving one typed desktop host
boundary.

#### Scenario: Linux packaged host launches a helper for native tunnel work

- **GIVEN** a packaged Linux desktop host that implements one documented
  `linux_tun` path
- **WHEN** startup needs privileged TUN, route, DNS, or cleanup work
- **THEN** the packaged Linux desktop host may reach a repo-owned privileged
  helper
- **AND** the Flutter shell still acts only as a typed consumer of capability,
  execution-plan, and startup result state
- **AND** the helper does not become a second public API surface for the shell

### Requirement: Linux privileged helpers receive only ephemeral execution inputs

The system SHALL keep provider resolution, transport-profile materialization,
and ordinary control-plane state outside the privileged Linux helper boundary.

#### Scenario: Linux helper receives one startup attempt

- **GIVEN** a packaged Linux desktop host starting one documented `linux_tun`
  startup attempt
- **WHEN** the host invokes the privileged helper
- **THEN** the helper receives only the ephemeral execution lease and
  host-owned route or policy directives for that attempt
- **AND** the helper does not own provider resolution, transport-profile store
  access, or shell persistence state
