## ADDED Requirements
### Requirement: Client control plane fails closed when provider-authenticated attach bootstrap lacks a verified execution tuple

The system SHALL fail explicitly before readiness when a provider-authenticated
conference attach bootstrap exists but the current host has not packaged and
verified a compatible same-device execution tuple.

#### Scenario: Shell requests same-device execution before the attach tuple is verified

- **GIVEN** a resolved `conference_room` artifact whose provider-specific
  attach bootstrap is documented
- **AND** the current host build has not verified a compatible same-device
  execution tuple for that bootstrap
- **WHEN** a shell requests same-device execution through that attach path
- **THEN** the host returns a typed failure before `ready=true`
- **AND** the failure identifies the missing verified execution tuple or
  carrier support
- **AND** the host does not fall back silently to `open_room`,
  `turn_credentials`, or guessed local execution
- **AND** the failure does not pretend that the attach boundary already chose a
  winning carrier when only the boundary itself is documented
