## ADDED Requirements
### Requirement: Client control plane negotiates the experimental WebRTC datachannel path explicitly

The system SHALL expose the experimental WebRTC datachannel runtime through
explicit plan metadata and capability negotiation instead of requiring shells to
guess from artifact family or provider name.

#### Scenario: Shell negotiates against a host without the experimental path

- **GIVEN** a shell build that understands the documented
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay` tuple
- **WHEN** it negotiates with a host that does not package or verify that path
- **THEN** the host does not advertise that path as supported
- **AND** the shell can keep the path hidden or unavailable without guessing
  from provider-specific heuristics

#### Scenario: Host reports the experimental path explicitly

- **GIVEN** a host build that exposes the documented WebRTC datachannel runtime
  as an experimental execution plan
- **WHEN** a shell reads the resolved artifact metadata through the control
  plane
- **THEN** the plan is serialized with explicit `access_method`,
  `carrier_family`, `engine_family`, and `remote_endpoint_family` metadata
- **AND** the shell does not need provider-name branching to identify that
  runtime path

### Requirement: Client control plane fails closed for missing attach or channel prerequisites

The system SHALL fail explicitly before readiness when the requested WebRTC
datachannel path lacks its attach target, capability, channel bring-up, or
runtime-attach prerequisite.

#### Scenario: Requested datachannel path cannot materialize attach state

- **GIVEN** a resolved artifact whose operator-facing room flow exists but whose
  repo-owned attach/runtime prerequisite is missing
- **WHEN** the shell requests startup through the documented WebRTC datachannel
  plan
- **THEN** the host returns a typed failure before `ready=true`
- **AND** the failure identifies the missing attach or startup prerequisite
- **AND** the host does not silently fall back to another execution path

#### Scenario: Requested datachannel path reaches ready state

- **GIVEN** a compatible host, an eligible artifact, and a verified repo-owned
  WebRTC datachannel runtime
- **WHEN** startup succeeds through the requested execution plan
- **THEN** the host reports readiness for that exact plan
- **AND** it does not conflate that ready state with TURN-backed
  `wireguard_native` or `turn_dtls_overlay` execution
