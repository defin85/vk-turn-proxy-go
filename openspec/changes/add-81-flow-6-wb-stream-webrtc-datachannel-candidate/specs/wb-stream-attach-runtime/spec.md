## ADDED Requirements
### Requirement: First explicit generic WB same-device candidate uses the explicit datachannel tuple

The system SHALL treat the first explicit generic WB same-device candidate as
the explicit conference-attach datachannel tuple rather than as TURN-backed
startup.

#### Scenario: Host advertises the first explicit generic WB same-device candidate

- **GIVEN** a resolved `wb-stream` `conference_room` artifact has a documented
  room-authenticated attach bootstrap
- **WHEN** the host reports the first explicit generic WB same-device candidate
  for that artifact
- **THEN** the candidate consumes `webrtc_call_attach`
- **AND** it names `carrier_family=webrtc_datachannel`
- **AND** it names `engine_family=custom_packet_overlay`
- **AND** it does not rename that candidate as `turn_credentials`
- **AND** it does not imply that every future WB same-device carrier must be
  `webrtc_datachannel`

### Requirement: WB datachannel candidacy does not exhaust the provider attach surface

The system SHALL document the WB datachannel tuple as one experimental
candidate on top of the WB attach surface rather than as the only possible WB
same-device carrier.

#### Scenario: Later evidence points to a provider-specific WB room data plane

- **GIVEN** the repository already documents the experimental WB datachannel
  tuple for `wb-stream`
- **WHEN** later evidence identifies a narrower provider-specific room data
  plane such as LiveKit room data packets
- **THEN** that later candidate may be specified separately
- **AND** the current WB datachannel change remains valid as a distinct
  candidate hypothesis
- **AND** the repository does not reinterpret provider-specific room data-plane
  evidence as proof of `webrtc_datachannel`

### Requirement: WB datachannel candidacy remains evidence-gated

The system SHALL keep the first WB datachannel tuple experimental until
repo-owned payload evidence exists.

#### Scenario: WB attach bootstrap exists but payload proof does not

- **GIVEN** the host can materialize room-authenticated WB attach/bootstrap
  state
- **AND** the repository has not yet proven repo-owned payload over the
  documented WB datachannel path
- **WHEN** a shell inspects the advertised WB same-device candidate
- **THEN** the host reports that candidate as experimental or unavailable
- **AND** it does not claim support from room join, relay allocation, or
  channel-open evidence alone
