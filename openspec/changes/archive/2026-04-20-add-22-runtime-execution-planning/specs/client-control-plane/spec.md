## ADDED Requirements
### Requirement: Client control plane negotiates runtime execution planning explicitly

The system SHALL advertise the runtime-execution-planning surface through an explicit host capability so updated shells can fail closed against hosts that still expose only artifact-family actions without typed execution plans.

#### Scenario: Updated shell negotiates against an older host

- **GIVEN** a shell build that expects typed runtime execution plans for host-owned same-device actions
- **WHEN** it negotiates with a host that does not implement the runtime-execution-planning surface
- **THEN** the host does not falsely claim that capability
- **AND** the shell can reject the host as incompatible before rendering plan-driven execution UX

### Requirement: Client control plane exposes typed runtime execution plans

The system SHALL expose typed runtime execution plans for supported host-owned same-device actions through the local control plane.

#### Scenario: Shell reads execution plans for a resolved artifact

- **GIVEN** a compatible host and a resolved artifact with one or more supported host-owned same-device actions
- **WHEN** a shell reads that artifact or requests its execution metadata through the control plane
- **THEN** the host returns the available runtime execution plans with explicit `access_method`, `carrier_family`, `engine_family`, optional `host_adapter`, and support-state metadata
- **AND** the shell does not need to recover those choices from provider-specific heuristics

#### Scenario: Shell requests an unavailable runtime execution plan

- **GIVEN** a resolved artifact and a host that exposes one or more runtime execution plans
- **WHEN** the shell requests startup through a plan that is unavailable, unsupported, or no longer valid for the current host build
- **THEN** the control plane fails explicitly before claiming readiness
- **AND** it identifies that requested execution plan as unavailable or unsupported
- **AND** it does not silently substitute another plan
