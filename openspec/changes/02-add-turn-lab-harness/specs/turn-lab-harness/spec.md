## ADDED Requirements

### Requirement: Repository provides a deterministic TURN lab harness

The system SHALL provide a reusable local lab harness that exercises a real TURN allocation path plus the DTLS tunnel server and UDP peer path.

#### Scenario: Start the harness for an integration test

- **GIVEN** an integration test or local smoke workflow
- **WHEN** the harness starts successfully
- **THEN** it exposes deterministic TURN credentials and a TURN endpoint
- **AND** it exposes a reachable DTLS peer server address
- **AND** it exposes an upstream UDP target that can be used to verify round-trip forwarding

#### Scenario: Stop the harness cleanly

- **GIVEN** a running harness instance
- **WHEN** the owning test or workflow cancels it
- **THEN** the TURN server, peer server, and upstream target stop cleanly
- **AND** the harness releases bound ports and background goroutines
