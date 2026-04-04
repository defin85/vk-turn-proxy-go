## MODIFIED Requirements
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

#### Scenario: Non-interactive captcha-required provider failure

- **GIVEN** a valid VK invite whose `vk_calls_get_anonymous_token` stage returns `error_code=14` and a challenge continuation URL
- **WHEN** the operator runs the probe without interactive provider handling enabled
- **THEN** the provider fails at `vk_calls_get_anonymous_token` with machine-readable code `captcha_required`
- **AND** no later VK or OK stages execute
- **AND** the persisted artifact records the challenge in sanitized form without raw session tokens

#### Scenario: Operator-assisted captcha continuation

- **GIVEN** a valid VK invite whose `vk_calls_get_anonymous_token` stage first returns `captcha_required`
- **AND** the operator runs the probe with interactive provider handling enabled
- **WHEN** the operator completes the VK challenge manually and confirms continuation
- **THEN** the provider retries the blocked stage and may continue stages 3 and 4
- **AND** successful completion still yields normalized TURN credentials
- **AND** the probe still does not start TURN, DTLS, or session transport loops

### Requirement: VK probe persists sanitized stage artifacts

The system SHALL persist sanitized debug artifacts for the VK provider exchange so compatibility work can compare the Go rewrite with the legacy oracle.

#### Scenario: Successful probe artifact capture

- **GIVEN** a successful VK invite resolution run
- **WHEN** the probe writes its debug output
- **THEN** it stores structured artifacts under the configured output directory
- **AND** the artifacts record the executed stage order and normalized outcome
- **AND** secrets such as tokens, TURN credentials, raw invite tokens, and raw captcha continuation tokens are redacted before persistence

#### Scenario: Provider stage failure artifact capture

- **GIVEN** a VK provider exchange that fails at a specific stage
- **WHEN** the probe exits with an error
- **THEN** it stores sanitized artifacts up to the failing stage
- **AND** the final error identifies the failing stage explicitly
- **AND** the system does not silently retry with fallback behavior

### Requirement: VK compatibility fixtures anchor provider behavior

The system SHALL keep compatibility fixtures and tests for the VK debug contour so provider behavior can be ported from the legacy repository with explicit evidence.

#### Scenario: Fixture-backed compatibility verification

- **GIVEN** sanitized fixtures derived from the legacy `getVkCreds` flow plus recorded captcha-required challenge fixtures for the rewrite
- **WHEN** compatibility tests replay the VK provider stages in the Go rewrite
- **THEN** the normalized TURN credentials, explicit stage failures, and interactive challenge handling match the fixture contract
- **AND** regressions in stage parsing, redaction, or continuation behavior fail the test suite
