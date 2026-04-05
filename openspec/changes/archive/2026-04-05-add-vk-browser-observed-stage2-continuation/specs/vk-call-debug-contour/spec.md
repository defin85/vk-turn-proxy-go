## MODIFIED Requirements
### Requirement: VK probe resolves invites into normalized TURN credentials

The system SHALL provide a provider-only debug contour for VK call invites that resolves a VK join link into normalized TURN credentials without starting transport sessions.

#### Scenario: Browser-observed repeated stage 2 succeeds after captcha gating

- **GIVEN** a valid VK invite whose first `vk_calls_get_anonymous_token` attempt returns `captcha_required`
- **AND** the operator runs the probe with interactive provider handling enabled
- **WHEN** the operator completes the challenge in a controlled browser session
- **AND** that same controlled browser session completes the native captcha continuation chain for VK stage 2
- **AND** the repeated `vk_calls_get_anonymous_token` response is observed from that browser-owned flow
- **THEN** the provider obtains the anonymous token from the browser-observed repeated stage-2 result
- **AND** stages 3 and 4 may continue to yield normalized TURN credentials
- **AND** the probe still does not start TURN, DTLS, or session transport loops

#### Scenario: Browser-observed continuation never yields a usable repeated stage 2 result

- **GIVEN** a valid VK invite whose first `vk_calls_get_anonymous_token` attempt returns `captcha_required`
- **AND** the operator runs the probe with interactive provider handling enabled
- **WHEN** the controlled browser session completes or attempts the native captcha continuation chain
- **AND** no usable repeated `vk_calls_get_anonymous_token` result is observed
- **OR** the observed repeated stage 2 result is still challenge-gated
- **THEN** the provider fails explicitly at `vk_calls_get_anonymous_token`
- **AND** the machine-readable error identifies the browser-observed stage-2 continuation failure

### Requirement: VK probe persists sanitized stage artifacts

The system SHALL persist sanitized debug artifacts for the VK provider exchange so compatibility work can compare the Go rewrite with the legacy oracle.

#### Scenario: Browser-observed continuation artifact capture

- **GIVEN** a VK provider exchange that uses browser-observed continuation for stage 2
- **WHEN** the probe writes its debug output
- **THEN** the artifact distinguishes the initial captcha-gated stage from the browser-observed repeated stage-2 result
- **AND** it does not persist raw browser cookies, profile paths, `session_token`, `success_token`, unredacted invite URLs, or raw continuation payload fields
