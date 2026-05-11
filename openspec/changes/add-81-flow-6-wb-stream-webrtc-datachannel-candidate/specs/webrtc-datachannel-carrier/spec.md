## ADDED Requirements
### Requirement: WB datachannel startup uses room-authenticated attach bootstrap

The system SHALL allow the experimental WebRTC datachannel tuple to start from
provider-authenticated WB attach/bootstrap state instead of from an ordinary
room-open flow.

#### Scenario: WB conference artifact advertises the datachannel tuple

- **GIVEN** a resolved `wb-stream` `conference_room` artifact whose host can
  truthfully materialize provider-authenticated attach/bootstrap state
- **WHEN** the host reports the experimental
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay` path
- **THEN** startup consumes the provider-owned WB attach/bootstrap contour
- **AND** ordinary reads do not expose raw bearer token, room token, or raw
  attach bootstrap fields
- **AND** the path remains distinct from `turn_credentials`
- **AND** the path is documented as one WB carrier candidate rather than as an
  exclusivity claim over the whole WB attach surface

### Requirement: WB datachannel carrier documentation remains non-exclusive

The system SHALL treat the experimental WB datachannel tuple as one documented
carrier candidate without forbidding a later provider-specific WB room-data-
plane sibling.

#### Scenario: Later WB evidence supports a provider-specific room data plane

- **GIVEN** the repository already documents the WB
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay` tuple
- **WHEN** later evidence supports a narrower provider-specific room data plane
  such as LiveKit room data packets
- **THEN** that sibling may be documented separately
- **AND** the existing datachannel tuple remains distinct
- **AND** provider-specific room-data-plane evidence alone does not prove the
  `webrtc_datachannel` carrier

### Requirement: WB datachannel readiness requires payload over the provider-owned call endpoint

The system SHALL require repo-owned payload evidence over the provider-owned WB
call endpoint before claiming that the experimental datachannel tuple is ready.

#### Scenario: Relay allocation or channel open is not enough for WB

- **GIVEN** a WB same-device candidate can gather relay candidates or open a
  datachannel attached to the provider-owned call endpoint
- **WHEN** the repository evaluates whether the WB datachannel tuple is ready
  for support claims
- **THEN** those signals alone are insufficient
- **AND** the evidence must prove repo-owned payload over the documented
  `webrtc_datachannel` carrier
- **AND** the repository does not infer readiness from TURN-only evidence
