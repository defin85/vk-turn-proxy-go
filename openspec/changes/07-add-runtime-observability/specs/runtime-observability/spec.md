## ADDED Requirements

### Requirement: Runtime emits structured operational signals

The system SHALL emit structured operational signals for provider-backed startup and long-running session behavior.

#### Scenario: Session startup and failure logging

- **GIVEN** a client or server runtime startup attempt
- **WHEN** startup succeeds or fails
- **THEN** the runtime emits structured events that identify the session, runtime stage, and result
- **AND** those events do not include raw invite tokens or raw credential secrets

### Requirement: Runtime exposes low-cardinality metrics

The system SHALL expose low-cardinality metrics for the main session and transport outcomes of long-running binaries.

#### Scenario: Observe runtime health

- **GIVEN** a running long-lived binary
- **WHEN** operators or tests inspect the metrics surface
- **THEN** they can observe session starts, session failures, active workers, startup-stage failures, and forwarded traffic
- **AND** metric labels stay within the documented low-cardinality dimensions
