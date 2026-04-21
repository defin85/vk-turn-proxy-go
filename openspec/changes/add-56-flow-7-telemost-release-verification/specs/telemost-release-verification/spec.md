## ADDED Requirements
### Requirement: Telemost support claims require repo-owned live evidence

The system SHALL treat Telemost support as reviewed only when the repository
has repo-owned live verification for the exact claimed Telemost surface.

#### Scenario: Community proof does not count as release verification

- **GIVEN** the repository has a community PoC, public room-join success, or
  anecdotal Telemost performance claims
- **WHEN** the repository evaluates whether Telemost is shipped or supported
- **THEN** those inputs may inform research only
- **AND** they do not count as release verification for operator-facing support

### Requirement: Telemost support is promoted per verified surface

The system SHALL promote Telemost support only for the exact surfaces that have
been verified live.

#### Scenario: Shell-external room opening is verified before same-device runtime

- **GIVEN** the repository has live verification for the ordinary
  `conference_room` Telemost flow and the committed `open_room` action
- **AND** no same-device Telemost runtime tuple has passed live verification
- **WHEN** the repository records current Telemost support status
- **THEN** it may promote only the verified room-open surface
- **AND** it does not imply that same-device Telemost runtime support also
  exists

#### Scenario: Same-device Telemost runtime is claimed as supported

- **GIVEN** the repository claims support for one same-device Telemost runtime
  tuple
- **WHEN** that claim is recorded in provider rollout or support-status
  artifacts
- **THEN** the claim is scoped to the exact verified auth posture, attach
  contract, carrier family, and engine family
- **AND** it is not conflated with generic Telemost support or with
  `generic_turn`

### Requirement: Telemost throughput and resilience claims are reproducible

The system SHALL back Telemost throughput or resilience claims with documented,
date-stamped repo-owned verification.

#### Scenario: Repository documents a Telemost speed advantage

- **GIVEN** the repository records that one Telemost path is faster or more
  resilient than another supported path
- **WHEN** that claim appears in support-status or rollout artifacts
- **THEN** the claim includes the exact verified date, runtime tuple, and
  documented measurement method
- **AND** stale or anecdotal numbers do not define the product contract
