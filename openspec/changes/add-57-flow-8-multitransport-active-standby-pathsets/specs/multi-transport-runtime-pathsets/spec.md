## ADDED Requirements
### Requirement: Runtime pathsets compose explicit child execution plans

The system SHALL describe multitransport same-device runtime through an
explicit pathset of child execution plans rather than through one opaque
multi-path mode string.

#### Scenario: Host advertises an active-standby pathset

- **GIVEN** a resolved artifact whose current build can support more than one
  documented child execution plan for one same-device runtime attempt
- **WHEN** the host reports the available same-device execution surface
- **THEN** it may advertise one pathset with a stable scheduler policy and an
  ordered list of child execution plans
- **AND** each child execution plan remains individually explicit
- **AND** the host does not collapse the child plans into one provider-specific
  or platform-specific mode string

### Requirement: Active-standby pathsets keep one active child path at a time

The system SHALL keep the first multitransport scheduler narrow as
`active_standby`.

#### Scenario: Standby path is promoted after active-path failure

- **GIVEN** a same-device runtime pathset whose scheduler policy is
  `active_standby`
- **WHEN** the active child path becomes unavailable according to the committed
  runtime health policy
- **THEN** the host may promote one eligible standby path into the active role
- **AND** the logical runtime session remains the same session attempt
- **AND** the host does not claim that both child paths were carrying runtime
  payload concurrently before that promotion

### Requirement: Pathset composition is compatibility-gated

The system SHALL fail closed when a requested multitransport pathset is not
part of the documented compatibility matrix.

#### Scenario: Unsupported child-plan mix is rejected

- **GIVEN** two or more child execution plans that are individually known to
  the host
- **WHEN** the current build has not documented or verified their joint use in
  one multitransport pathset
- **THEN** the host rejects that pathset before startup
- **AND** it does not synthesize a guessed failover relationship between those
  plans

### Requirement: Active-standby support does not imply bandwidth aggregation

The system SHALL not treat active-standby multitransport as proof of aggregate
throughput or packet striping support.

#### Scenario: Active-standby pathset is reported as supported

- **GIVEN** a host build that supports one `active_standby` pathset
- **WHEN** that support is reported through the host contract or operator docs
- **THEN** the support claim is scoped to failover and path promotion behavior
- **AND** it does not imply packet striping, active-active scheduling, or
  additive bandwidth across child paths
