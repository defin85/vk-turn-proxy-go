## MODIFIED Requirements
### Requirement: Repository provides a deterministic TURN lab harness

The repository SHALL provide a reusable local TURN lab harness for deterministic transport integration tests.

#### Scenario: Runtime integration test boots the harness

- **GIVEN** an integration test that needs a local TURN-backed path
- **WHEN** the test starts the harness
- **THEN** the harness exposes deterministic TURN credentials and peer endpoints that the runtime can consume without external services
- **AND** the harness can be shut down cleanly by the test process

#### Scenario: Long-lived transport maintenance is exercised deterministically

- **GIVEN** an integration test that needs to hold a supported session across a maintenance window
- **WHEN** the test starts the harness in long-lived mode
- **THEN** the harness provides deterministic conditions for allocation or permission maintenance to occur
- **AND** the test can verify whether the runtime stayed healthy through that window without relying on live external providers
