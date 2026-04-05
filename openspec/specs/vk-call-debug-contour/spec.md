# vk-call-debug-contour Specification

## Purpose
Define the provider-only VK invite debug contour that resolves normalized TURN credentials and persists sanitized stage artifacts for compatibility work without starting transport sessions.
## Requirements
### Requirement: VK probe resolves invites into normalized TURN credentials

The system SHALL provide a provider-only VK invite debug contour that can distinguish deterministic legacy staged behavior, browser-observed preview behavior, and browser-observed post-preview behavior without starting transport sessions.

#### Scenario: Browser-observed post-preview contour is captured after live preview

- **GIVEN** a live VK browser contour that reaches the pre-join preview page after captcha completion
- **WHEN** the operator proceeds in the controlled browser past the preview UI and the probe continues observing the live browser session
- **THEN** the provider records the ordered post-preview browser contour explicitly
- **AND** it does not collapse that evidence into the earlier preview-only result

#### Scenario: Browser-observed post-preview contour still does not yield TURN credentials

- **GIVEN** a live VK browser contour that progresses beyond `calls.getCallPreview`
- **WHEN** the observed post-preview requests still do not expose normalized TURN credentials
- **THEN** the provider fails closed with an explicit post-preview provider-stage result
- **AND** the probe still does not start TURN, DTLS, or session transport loops

### Requirement: VK probe persists sanitized stage artifacts

The system SHALL persist sanitized debug artifacts for deterministic legacy VK exchanges, browser-observed preview exchanges, and browser-observed post-preview exchanges.

#### Scenario: Post-preview artifact capture

- **GIVEN** a controlled browser run that progresses beyond preview
- **WHEN** the probe writes its debug output
- **THEN** the artifact preserves the ordered post-preview request and outcome labels for that live contour
- **AND** it redacts invite tokens, browser tokens, short links, profile PII, cookies, and other live browser-only state

### Requirement: VK compatibility fixtures anchor provider behavior

The system SHALL keep compatibility fixtures and tests for live browser preview and post-preview contours so new evidence can be replayed deterministically in the Go rewrite.

#### Scenario: Fixture-backed post-preview verification

- **GIVEN** sanitized fixtures derived from browser-observed post-preview live evidence
- **WHEN** compatibility tests replay the VK provider stages in the Go rewrite
- **THEN** the explicit contour outcome matches the fixture contract
- **AND** regressions in post-preview parsing, ordering, or sanitization fail the test suite

