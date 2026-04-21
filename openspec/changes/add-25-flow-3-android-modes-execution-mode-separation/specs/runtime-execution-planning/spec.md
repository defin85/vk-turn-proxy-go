## ADDED Requirements
### Requirement: Android detection-surface assumptions are mode-specific

The system SHALL keep Android detection-surface assumptions tied to the
documented runtime execution plan instead of treating them as a generic mobile
property.

#### Scenario: `android_vpn_service` plan keeps system-tunnel semantics

- **GIVEN** a documented runtime execution plan whose host adapter is
  `android_vpn_service`
- **WHEN** the repository describes that plan
- **THEN** the plan keeps Android system-tunnel semantics
- **AND** the host does not imply that the plan is equivalent to a future
  non-system Android relay mode

#### Scenario: Future Android non-system plan needs its own execution tuple

- **GIVEN** a future Android runtime that claims a different scope or detection
  surface from `android_vpn_service`
- **WHEN** the repository adds that runtime to execution planning
- **THEN** it appears as its own documented execution tuple
- **AND** it does not reuse the `android_vpn_service` tuple by implication
