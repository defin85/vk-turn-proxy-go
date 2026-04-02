# vk-call-debug-contour Specification

## Purpose
Define the provider-only VK invite debug contour that resolves normalized TURN credentials and persists sanitized stage artifacts for compatibility work without starting transport sessions.
## Requirements
### Requirement: VK probe resolves invites into normalized TURN credentials

The system SHALL provide a provider-only debug contour for VK call invites that resolves a VK join link into normalized TURN credentials without starting transport sessions.

#### Scenario: Successful VK invite resolution

- **GIVEN** a valid VK call invite link and a staged VK provider exchange that returns the required tokens and TURN server fields
- **WHEN** the operator runs the probe against the VK provider
- **THEN** the system returns normalized TURN credentials including username, password, and TURN address
- **AND** the returned TURN address omits the `turn:` or `turns:` prefix and any query string suffix
- **AND** the probe does not start TURN, DTLS, or session transport loops

#### Scenario: Malformed invite input

- **GIVEN** an empty or malformed VK invite input
- **WHEN** the operator runs the probe against the VK provider
- **THEN** the system fails before network stage execution
- **AND** the error explicitly identifies the invalid VK link input

### Requirement: VK probe persists sanitized stage artifacts

The system SHALL persist sanitized debug artifacts for the VK provider exchange so compatibility work can compare the Go rewrite with the legacy oracle.

#### Scenario: Successful probe artifact capture

- **GIVEN** a successful VK invite resolution run
- **WHEN** the probe writes its debug output
- **THEN** it stores structured artifacts under the configured output directory
- **AND** the artifacts record the executed stage order and normalized outcome
- **AND** secrets such as tokens, TURN credentials, and raw invite tokens are redacted before persistence

#### Scenario: Provider stage failure artifact capture

- **GIVEN** a VK provider exchange that fails at a specific stage
- **WHEN** the probe exits with an error
- **THEN** it stores sanitized artifacts up to the failing stage
- **AND** the final error identifies the failing stage explicitly
- **AND** the system does not silently retry with fallback behavior

### Requirement: VK compatibility fixtures anchor provider behavior

The system SHALL keep compatibility fixtures and tests for the VK debug contour so provider behavior can be ported from the legacy repository with explicit evidence.

#### Scenario: Fixture-backed compatibility verification

- **GIVEN** sanitized fixtures derived from the legacy `getVkCreds` flow
- **WHEN** compatibility tests replay the VK provider stages in the Go rewrite
- **THEN** the normalized TURN credentials and explicit failure cases match the fixture contract
- **AND** regressions in stage parsing or normalization fail the test suite
