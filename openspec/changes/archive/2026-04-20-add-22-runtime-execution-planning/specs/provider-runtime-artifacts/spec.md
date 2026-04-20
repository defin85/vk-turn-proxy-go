## ADDED Requirements
### Requirement: Resolved artifacts advertise typed access methods for same-device execution

The system SHALL let a resolved artifact advertise the typed `access_method` values that host-owned same-device actions may consume, separately from the artifact family itself.

#### Scenario: Generic TURN artifact exposes TURN access methods

- **GIVEN** a resolved artifact whose family is `generic_turn`
- **WHEN** the host reports the supported host-owned same-device actions and their planning metadata for that artifact
- **THEN** the artifact advertises `turn_credentials` or another documented TURN-backed access method explicitly
- **AND** the host does not require the shell to infer that access method from the artifact family name alone

#### Scenario: Conference artifact does not masquerade as TURN

- **GIVEN** a resolved artifact whose family is `conference_room`
- **WHEN** the host reports access methods or actions for that artifact
- **THEN** it may advertise `webrtc_call_attach`, `open_room`, or another documented conference-appropriate path
- **AND** it does not imply `turn_credentials` unless the provider also resolved a separate TURN-backed access surface
