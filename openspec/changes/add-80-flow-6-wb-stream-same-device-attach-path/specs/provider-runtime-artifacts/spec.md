## ADDED Requirements
### Requirement: Provider-authenticated conference bootstrap does not imply TURN access

The system SHALL keep provider-authenticated conference attach bootstrap
separate from TURN-backed access methods even when that bootstrap includes ICE
or TURN configuration.

#### Scenario: Host reports provider-authenticated conference bootstrap

- **GIVEN** a resolved artifact whose family is `conference_room`
- **AND** the provider-owned attach bootstrap includes a room token, signaling
  endpoint, or ICE/TURN configuration gathered under authenticated room state
- **WHEN** the host reports access methods, actions, or ordinary reads for that
  artifact
- **THEN** the host may advertise `webrtc_call_attach` or another documented
  conference-appropriate attach path
- **AND** it does not advertise `turn_credentials` from those ICE/TURN lines
  alone
- **AND** ordinary reads keep the provider-authenticated attach bootstrap
  redacted
- **AND** ordinary reads do not imply that one specific non-TURN carrier has
  already been chosen unless a later documented candidate says so
