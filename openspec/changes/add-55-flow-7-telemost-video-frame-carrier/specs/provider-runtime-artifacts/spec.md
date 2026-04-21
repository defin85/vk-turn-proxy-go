## ADDED Requirements
### Requirement: Attachable conference artifacts advertise video-frame support explicitly

The system SHALL advertise the video-frame path only from artifacts that expose
one documented attachable conference surface.

#### Scenario: Conference artifact advertises video-frame attach

- **GIVEN** a resolved artifact whose family is `conference_room`
- **AND** the current host build can truthfully materialize a repo-owned attach
  target for that artifact
- **WHEN** the host reports access methods and supported actions for the
  artifact
- **THEN** it may advertise `webrtc_call_attach`
- **AND** it may report a same-device execution plan for
  `webrtc_video_frames + custom_packet_overlay`
- **AND** it does not flatten that path into `turn_credentials`

#### Scenario: Non-attachable artifact does not claim the video-frame path

- **GIVEN** a resolved artifact that lacks a documented attachable conference
  surface
- **WHEN** the host reports access methods and supported actions for that
  artifact
- **THEN** it does not advertise `webrtc_call_attach`
- **AND** it does not imply a repo-owned `webrtc_video_frames` runtime path
  from an ordinary `open_room` action alone
