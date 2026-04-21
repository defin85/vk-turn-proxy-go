## ADDED Requirements
### Requirement: Eligible artifacts expose an explicit video-frame runtime tuple

The system SHALL treat the first repo-owned video-frame path as an explicit
runtime tuple instead of as a generic conference shortcut.

#### Scenario: Host reports an attachable video-frame execution plan

- **GIVEN** a resolved artifact that truthfully supports host-owned same-device
  execution through an attachable conference surface
- **WHEN** the host reports the available execution plans for that artifact
- **THEN** the plan names `access_method=webrtc_call_attach`
- **AND** it names `carrier_family=webrtc_video_frames`
- **AND** it names `engine_family=custom_packet_overlay`
- **AND** it names `remote_endpoint_family=webrtc_call_endpoint`
- **AND** the host does not present that path as TURN-backed or as
  `webrtc_datachannel`

### Requirement: Video-frame attach materialization stays host-owned and redacted

The system SHALL materialize and consume secret-bearing attach or bootstrap
state for the video-frame carrier inside the host boundary.

#### Scenario: Shell requests startup through the video-frame path

- **GIVEN** an eligible artifact and a requested execution plan for
  `webrtc_call_attach + webrtc_video_frames + custom_packet_overlay`
- **WHEN** the shell requests startup through the local control plane
- **THEN** the host materializes the attach or bootstrap state internally
- **AND** ordinary reads, shell state, and diagnostic summaries do not expose
  raw attach or publish secrets
- **AND** the shell receives typed success or failure state instead of a raw
  provider-specific attach blob

### Requirement: Video-frame support remains experimental and non-default

The system SHALL keep the first repo-owned video-frame path experimental,
non-default, and fail-closed until explicit verification exists.

#### Scenario: Host lacks verified video-frame support

- **GIVEN** a host build that does not package or verify the documented
  video-frame runtime
- **WHEN** a shell inspects execution plans or requests that path
- **THEN** the host reports the path as unavailable or experimental
- **AND** it does not auto-select that path as a default same-device runtime
- **AND** startup fails explicitly before any `ready=true` claim

### Requirement: Ready state requires overlay payload over published video frames

The system SHALL require repo-owned evidence that actual overlay payload
traffic crosses the documented video-frame carrier before claiming supported
startup for that path.

#### Scenario: Room join or frame pump alone is insufficient

- **GIVEN** a host that can join a room, publish a video track, or keep a
  frame pump alive
- **WHEN** the repository evaluates whether the path is ready for support
  claims
- **THEN** those signals alone are insufficient
- **AND** the evidence must prove that repo-owned runtime payload traffic flows
  across the documented video-frame carrier
