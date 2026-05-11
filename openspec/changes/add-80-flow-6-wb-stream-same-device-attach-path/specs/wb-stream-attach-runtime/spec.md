## ADDED Requirements
### Requirement: WB same-device attach starts from room-authenticated bootstrap

The system SHALL model WB same-device execution as a room-authenticated attach
bootstrap rather than as a transport-ready TURN export.

#### Scenario: Host materializes WB attach prerequisites from room-authenticated state

- **GIVEN** a supported `wb-stream` room has reached provider-authenticated
  room state in an approved browser or app continuation surface
- **WHEN** the host materializes WB same-device attach prerequisites for that
  room
- **THEN** it uses provider-owned attach bootstrap such as documented
  `connection-details`, `serverUrl`, `roomToken`, and device identity inputs
- **AND** access tokens, room tokens, and other secret-bearing attach fields
  remain inside the host boundary
- **AND** the host does not reinterpret the room as `generic_turn` only
  because ICE or TURN lines are present

### Requirement: TURN relay evidence alone is insufficient for WB support claims

The system SHALL treat bare WB TURN or ICE evidence as insufficient for
same-device support claims.

#### Scenario: Relay allocation alone does not make WB supportable

- **GIVEN** a WB room-authenticated attach bootstrap yields ICE/TURN
  configuration or relay candidates
- **WHEN** the repository evaluates whether WB same-device attach is
  supportable
- **THEN** relay allocation, ICE gathering, or bare TURN connectivity alone
  are insufficient
- **AND** support claims require repo-owned payload evidence against the
  provider-owned call endpoint
- **AND** the repository does not claim a packaged TURN-backed tuple from that
  evidence alone

### Requirement: Ordinary `open_room` and same-device attach remain separate WB surfaces

The system SHALL keep the already-committed shell-external WB room-open flow
separate from any future same-device attach runtime.

#### Scenario: Host has no verified WB same-device tuple yet

- **GIVEN** a resolved `wb-stream` `conference_room` artifact still supports
  shell-external `open_room`
- **WHEN** the current host build has not verified a WB same-device execution
  tuple
- **THEN** ordinary reads continue to advertise `open_room`
- **AND** they do not claim supported local execution
- **AND** any future same-device WB path requires a later explicit
  execution-plan advertisement

### Requirement: WB same-device plans use conference attach semantics

The system SHALL keep any future WB same-device runtime on explicit conference
attach semantics rather than renaming it as transport-ready TURN.

#### Scenario: Host later reports a WB same-device plan

- **GIVEN** a host later reports a same-device execution plan for a
  `wb-stream` room
- **WHEN** a shell reads the documented plan metadata
- **THEN** the plan consumes `webrtc_call_attach` or another documented
  conference-attach access method
- **AND** it does not rename that path as `turn_credentials` unless a separate
  transport-ready artifact also exists

### Requirement: WB attach boundary stays carrier-neutral

The system SHALL treat the WB attach boundary as carrier-neutral until later
payload evidence chooses a documented same-device carrier.

#### Scenario: Later work evaluates multiple WB carrier candidates

- **GIVEN** the repository has already documented a room-authenticated WB
  attach/bootstrap boundary
- **WHEN** later changes evaluate a generic `webrtc_datachannel` tuple, a
  provider-specific room-data-plane path, or another documented non-TURN
  carrier
- **THEN** each candidate may reuse the same WB attach boundary
- **AND** the boundary itself does not pre-claim which carrier will win
- **AND** provider-owned room-data-plane evidence does not by itself rename WB
  as `generic_turn`
