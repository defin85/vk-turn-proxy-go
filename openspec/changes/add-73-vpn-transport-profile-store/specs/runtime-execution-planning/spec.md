## ADDED Requirements

### Requirement: Runtime plans declare required transport profile material

The system SHALL let runtime execution plans declare any required VPN transport
profile kinds, material sources, and compatibility prerequisites separately
from `access_method`, `carrier_family`, `engine_family`, and `host_adapter`.

#### Scenario: WireGuard-native plan requires a compatible profile

- **GIVEN** a packaged host advertises a strict `turn_datagram`
  `wireguard_native` plan for a platform tunnel adapter
- **WHEN** the shell reads the execution-plan metadata
- **THEN** the plan declares that it requires a compatible
  `wireguard_native_v1` transport profile or another explicitly documented
  host-owned material source with equivalent redaction and lifecycle semantics
- **AND** the shell does not infer that requirement from a hidden file name or
  host-specific environment variable

#### Scenario: Plan without transport profile prerequisite stays independent

- **GIVEN** a future execution plan uses an engine family that does not require
  app-owned VPN transport profile material
- **WHEN** the host reports that plan
- **THEN** the plan can declare no required transport profile kind
- **AND** the shell does not force the WireGuard import workflow for that plan

### Requirement: Execution planning reports profile prerequisite state

The system SHALL expose missing, invalid, incompatible, and ready transport
profile prerequisite state as part of plan support metadata so shells can
render setup-needed states before startup.

#### Scenario: Profile prerequisite is missing

- **GIVEN** a host supports an adapter and engine in principle
- **AND** the selected plan requires a transport profile that is not configured
- **WHEN** the shell reads available execution plans
- **THEN** the plan remains visible only with a setup-needed or unavailable
  support state
- **AND** the metadata identifies the missing transport profile kind
- **AND** the metadata exposes the operator-visible setup action or import
  adapter family needed to satisfy that prerequisite

#### Scenario: Profile prerequisite is satisfied

- **GIVEN** a compatible transport profile is configured for the selected host
  and execution plan
- **WHEN** the shell reads available execution plans
- **THEN** the host may report that plan as startable with the selected or
  default profile reference
- **AND** startup still revalidates the profile before readiness is reported

#### Scenario: Older host lacks profile-store capability

- **GIVEN** a host reports a platform tunnel adapter but does not advertise the
  VPN transport profile store capability
- **WHEN** a plan requires profile-store material
- **THEN** the plan is unavailable for that host
- **AND** the shell does not render it as startable based on adapter support
  alone
