## ADDED Requirements
### Requirement: Client control plane negotiates the video-frame path explicitly

The system SHALL expose the video-frame runtime through explicit plan metadata
and capability negotiation instead of requiring shells to infer it from
provider name or artifact family alone.

#### Scenario: Shell negotiates against a host without the video-frame path

- **GIVEN** a shell build that understands the documented
  `webrtc_call_attach + webrtc_video_frames + custom_packet_overlay` tuple
- **WHEN** it negotiates with a host that does not package or verify that path
- **THEN** the host does not advertise that path as supported
- **AND** the shell can keep the path hidden or unavailable without guessing
  from provider-specific heuristics

#### Scenario: Host reports the video-frame path explicitly

- **GIVEN** a host build that exposes the documented video-frame runtime as an
  experimental execution plan
- **WHEN** a shell reads the resolved artifact metadata through the control
  plane
- **THEN** the plan is serialized with explicit `access_method`,
  `carrier_family`, `engine_family`, and `remote_endpoint_family` metadata
- **AND** the shell does not need provider-name branching to identify that
  runtime path

### Requirement: Client control plane fails closed for missing video-frame prerequisites

The system SHALL fail explicitly before readiness when the requested
video-frame path lacks its attach target, frame-publisher prerequisite, or
runtime-attach prerequisite.

#### Scenario: Requested video-frame path cannot materialize publish state

- **GIVEN** a resolved artifact whose ordinary room-open flow exists but whose
  repo-owned attach or frame-publish prerequisite is missing
- **WHEN** the shell requests startup through the documented video-frame plan
- **THEN** the host returns a typed failure before `ready=true`
- **AND** the failure identifies the missing attach or startup prerequisite
- **AND** the host does not silently fall back to another execution path

#### Scenario: Requested video-frame path reaches ready state

- **GIVEN** a compatible host, an eligible artifact, and a verified repo-owned
  video-frame runtime
- **WHEN** startup succeeds through the requested execution plan
- **THEN** the host reports readiness for that exact plan
- **AND** it does not conflate that ready state with TURN-backed or
  datachannel-backed execution
