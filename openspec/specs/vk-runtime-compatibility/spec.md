# vk-runtime-compatibility Specification

## Purpose
Anchor the supported VK-backed client runtime slice with explicit, replayable compatibility evidence so future runtime changes can be checked against the legacy oracle and documented deviations.
## Requirements
### Requirement: Supported VK runtime behavior is anchored by explicit compatibility evidence

The system SHALL keep explicit compatibility evidence for the supported VK-backed client runtime slice so future changes can be checked against the legacy oracle.

#### Scenario: Successful supported-slice compatibility case

- **GIVEN** the supported VK-backed client runtime slice
- **WHEN** compatibility verification is run against the recorded evidence set
- **THEN** the startup and forwarding expectations for that supported slice match the recorded contract
- **AND** regressions fail verification with explicit scenario names

#### Scenario: Intentional deviation from unsupported legacy behavior

- **GIVEN** a legacy behavior that is outside the supported rewrite slice
- **WHEN** compatibility documentation is reviewed
- **THEN** the deviation is called out explicitly
- **AND** the rewrite does not imply parity for that unsupported behavior
