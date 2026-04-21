## ADDED Requirements
### Requirement: Eligible artifacts expose an explicit WebRTC datachannel runtime tuple

The system SHALL treat the first repo-owned non-WireGuard execution path as an
explicit runtime tuple instead of as a generic "conference mode" shortcut.

#### Scenario: Host reports an attachable WebRTC datachannel plan

- **GIVEN** a resolved artifact that truthfully supports host-owned same-device
  execution through an attachable room or call surface
- **WHEN** the host reports the available execution plans for that artifact
- **THEN** the plan names `access_method=webrtc_call_attach`
- **AND** it names `carrier_family=webrtc_datachannel`
- **AND** it names `engine_family=custom_packet_overlay`
- **AND** it names `remote_endpoint_family=webrtc_call_endpoint`
- **AND** the host does not present that path as TURN-backed or as a packaged
  system-tunnel mode

### Requirement: Attach materialization stays host-owned and redacted

The system SHALL materialize and consume secret-bearing WebRTC attach state
inside the host boundary rather than serializing raw attach blobs through
ordinary shell-facing reads.

#### Scenario: Shell requests startup through the experimental datachannel path

- **GIVEN** an eligible artifact and a requested execution plan for
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay`
- **WHEN** the shell requests startup through the local control plane
- **THEN** the host materializes the attach/session state internally
- **AND** ordinary resolution reads, shell state, and diagnostic summaries do
  not expose raw room-scoped attach secrets
- **AND** the shell receives typed success or failure state instead of a raw
  provider-specific attach blob

### Requirement: WebRTC datachannel support remains capability-gated and non-default

The system SHALL keep the first repo-owned WebRTC datachannel path
experimental, non-default, and fail-closed until the implementation is
explicitly verified.

#### Scenario: Host lacks verified experimental datachannel support

- **GIVEN** a host build that does not package or verify the documented
  WebRTC datachannel runtime
- **WHEN** a shell inspects execution plans or requests that path
- **THEN** the host reports the path as unavailable or experimental
- **AND** it does not auto-select that path as a default same-device runtime
- **AND** startup fails explicitly before any `ready=true` claim

### Requirement: Ready state requires real payload traffic over the datachannel carrier

The system SHALL require repo-owned evidence that actual overlay payload traffic
crosses the `webrtc_datachannel` carrier before claiming supported startup for
that path.

#### Scenario: Channel bring-up alone is not enough

- **GIVEN** a host that can open or attach a WebRTC datachannel
- **WHEN** the repository evaluates whether the path is ready for support claims
- **THEN** successful signaling or channel-open events alone are insufficient
- **AND** the evidence must prove that repo-owned runtime payload traffic flows
  across the documented datachannel carrier
