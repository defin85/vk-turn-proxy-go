## ADDED Requirements
### Requirement: Platform tunnel support is capability-gated and explicit

The system SHALL expose platform tunnel support as an explicit capability instead of assuming that every host can capture system traffic.

#### Scenario: Host lacks required tunnel capability

- **GIVEN** a client shell running on a platform that lacks a required entitlement, permission, driver, or tunnel primitive
- **WHEN** the operator attempts to enable system-wide tunnel mode
- **THEN** the host reports the missing capability explicitly
- **AND** the client does not silently fall back to a partial or undefined tunnel mode

#### Scenario: Host supports tunnel mode

- **GIVEN** a platform host that satisfies the documented tunnel prerequisites
- **WHEN** the client queries host capabilities
- **THEN** the host reports system tunnel support explicitly
- **AND** the client may offer the documented tunnel workflow for that platform

### Requirement: Platform tunnel startup fails closed on unsafe routing prerequisites

The system SHALL validate route preparation and exclusion prerequisites before claiming system tunnel readiness.

#### Scenario: Required route exclusions are missing

- **GIVEN** a platform tunnel mode that requires explicit exclusion or bypass rules for control traffic
- **WHEN** startup validation finds that those exclusions are missing or invalid
- **THEN** startup fails before the client claims readiness
- **AND** the failure is surfaced as a documented platform tunnel startup error

#### Scenario: Tunnel host starts safely

- **GIVEN** a platform host with the required tunnel capability and route prerequisites
- **WHEN** the operator starts system tunnel mode
- **THEN** the host establishes the documented tunnel path for that platform
- **AND** readiness is reported only after the host-specific tunnel prerequisites succeed

### Requirement: Platform tunnel integrations remain separate from provider behavior

The system SHALL keep OS-specific tunnel behavior separate from provider-specific signaling and credential resolution.

#### Scenario: Provider challenge occurs during a tunnel-capable client flow

- **GIVEN** a client profile that may later use platform tunnel mode
- **WHEN** provider resolution requires a browser challenge or other operator action
- **THEN** the provider challenge flow remains governed by the provider and control-plane contracts
- **AND** the platform tunnel integration does not add hidden provider-specific fallback behavior
