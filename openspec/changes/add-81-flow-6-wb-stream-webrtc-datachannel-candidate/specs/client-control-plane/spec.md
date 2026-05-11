## ADDED Requirements
### Requirement: Client control plane exposes the WB datachannel candidate as experimental

The system SHALL let hosts advertise the first WB datachannel tuple explicitly
while still keeping it experimental and fail-closed.

#### Scenario: Host knows the WB candidate but has not verified payload-ready support

- **GIVEN** a resolved `wb-stream` artifact has documented
  room-authenticated attach/bootstrap support
- **AND** the host understands the
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay` tuple for
  WB
- **WHEN** a shell reads same-device execution metadata for that artifact
- **THEN** the host may advertise the WB datachannel tuple explicitly
- **AND** it reports the tuple as experimental or unavailable until payload
  verification exists
- **AND** the shell does not need provider-name heuristics to discover that
  candidate
- **AND** the control plane does not imply that this tuple exhausts all future
  WB same-device candidates

### Requirement: Client control plane fails closed when WB datachannel support is not yet payload-ready

The system SHALL fail explicitly before readiness when WB attach/bootstrap
exists but payload-ready datachannel support is not yet verified.

#### Scenario: Shell requests WB datachannel startup too early

- **GIVEN** a shell requests startup through the documented WB datachannel
  tuple
- **AND** the host can materialize WB attach/bootstrap state but has not
  verified payload-ready runtime support
- **WHEN** the startup request reaches the control plane
- **THEN** the host returns a typed failure before `ready=true`
- **AND** it identifies the missing payload-ready support or verification gate
- **AND** it does not fall back silently to `open_room` or TURN-backed startup
