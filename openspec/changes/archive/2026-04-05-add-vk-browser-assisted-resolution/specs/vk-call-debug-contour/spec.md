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

#### Scenario: Browser-assisted continuation after captcha-required stage

- **GIVEN** a valid VK invite whose first `vk_calls_get_anonymous_token` attempt returns `captcha_required`
- **AND** the operator runs the probe with interactive provider handling enabled
- **WHEN** the operator completes the challenge inside a controlled browser session used for provider continuation
- **THEN** the provider may resume stage 2 using browser-assisted session state
- **AND** successful continuation may proceed through stages 3 and 4 to yield normalized TURN credentials
- **AND** the probe still does not start TURN, DTLS, or session transport loops

#### Scenario: Browser-assisted continuation is unavailable

- **GIVEN** a valid VK invite whose first `vk_calls_get_anonymous_token` attempt returns `captcha_required`
- **WHEN** browser-assisted continuation cannot be started or cannot supply the required session state
- **THEN** the provider fails explicitly at `vk_calls_get_anonymous_token`
- **AND** the failing code identifies the browser-assisted continuation failure without implying successful VK parity

### Requirement: VK probe persists sanitized stage artifacts

The system SHALL persist sanitized debug artifacts for the VK provider exchange so compatibility work can compare the Go rewrite with the legacy oracle.

#### Scenario: Successful probe artifact capture

- **GIVEN** a successful VK invite resolution run
- **WHEN** the probe writes its debug output
- **THEN** it stores structured artifacts under the configured output directory
- **AND** the artifacts record the executed stage order and normalized outcome
- **AND** secrets such as tokens, TURN credentials, raw invite tokens, and raw browser-session artifacts are redacted before persistence

#### Scenario: Provider stage failure artifact capture

- **GIVEN** a VK provider exchange that fails at a specific stage
- **WHEN** the probe exits with an error
- **THEN** it stores sanitized artifacts up to the failing stage
- **AND** the final error identifies the failing stage explicitly
- **AND** the system does not silently retry with fallback behavior
