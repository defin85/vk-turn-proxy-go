## MODIFIED Requirements
### Requirement: VK probe resolves invites into normalized TURN credentials

The system SHALL provide a provider-only VK invite debug contour that can distinguish deterministic legacy staged behavior from browser-observed live browser behavior without starting transport sessions.

#### Scenario: Live browser contour reaches pre-join preview after challenge

- **GIVEN** a valid VK invite whose browser flow is redirected through `challenge.html`
- **WHEN** the operator completes the challenge in a controlled browser session
- **AND** the browser reaches the pre-join preview page through browser-observed requests such as `get_anonym_token(messages)` and `calls.getCallPreview`
- **THEN** the provider records that browser preview contour explicitly
- **AND** it does not keep waiting for a repeated `vk_calls_get_anonymous_token` request that did not occur

#### Scenario: Live browser contour does not yet yield TURN credentials

- **GIVEN** a live VK browser contour that reaches the pre-join preview page but does not expose normalized TURN credentials
- **WHEN** the operator runs the probe
- **THEN** the provider fails closed with an explicit provider-stage result that identifies the preview-only or unsupported live contour
- **AND** the probe still does not start TURN, DTLS, or session transport loops

### Requirement: VK probe persists sanitized stage artifacts

The system SHALL persist sanitized debug artifacts for both deterministic legacy VK provider exchanges and browser-observed live VK browser exchanges.

#### Scenario: Live browser preview artifact capture

- **GIVEN** a VK browser exchange that reaches the pre-join preview page after challenge completion
- **WHEN** the probe writes its debug output
- **THEN** the artifact preserves the observed browser request order and outcome labels for that live contour
- **AND** it redacts raw invite tokens, browser tokens, cookies, challenge URLs, and other browser-only state
