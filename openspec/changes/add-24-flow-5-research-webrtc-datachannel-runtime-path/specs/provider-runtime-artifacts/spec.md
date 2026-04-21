## ADDED Requirements
### Requirement: Attachable room artifacts do not masquerade as TURN or generic room-open flows

The system SHALL advertise the experimental WebRTC datachannel path only from
artifacts that expose a documented attachable call surface.

#### Scenario: Conference artifact advertises `webrtc_call_attach`

- **GIVEN** a resolved artifact whose family is `conference_room`
- **AND** the current host build can truthfully materialize a repo-owned attach
  target for that artifact
- **WHEN** the host reports access methods and supported actions for the
  artifact
- **THEN** it may advertise `webrtc_call_attach`
- **AND** it may report a same-device execution plan for
  `webrtc_datachannel + custom_packet_overlay`
- **AND** it does not flatten that path into `turn_credentials`

#### Scenario: Non-attachable artifact does not claim the datachannel path

- **GIVEN** a resolved artifact that lacks a documented attachable call surface
- **WHEN** the host reports access methods and supported actions for that
  artifact
- **THEN** it does not advertise `webrtc_call_attach`
- **AND** it does not imply a repo-owned `webrtc_datachannel` runtime path from
  an ordinary room-open action, camera action, or TURN artifact alone
