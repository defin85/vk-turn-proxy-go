## ADDED Requirements
### Requirement: Telemost remains legacy-only until a reviewed support surface exists

The system SHALL keep `yandex-telemost` out of ordinary shipped provider
support until the repository has a committed provider contract and repo-owned
release verification for the exact claimed Telemost support surface.

#### Scenario: Legacy Telemost reference does not imply shipped support

- **GIVEN** the repository contains a provider-matrix entry, research note, or
  other legacy reference to `yandex-telemost`
- **WHEN** no committed Telemost provider contract and release verification
  have promoted that surface into supported status
- **THEN** the ordinary operator-facing provider catalog does not treat
  `yandex-telemost` as shipped support
- **AND** the repository does not imply that legacy references are equivalent
  to reviewed product support

### Requirement: Telemost admission distinguishes room creation from runtime attach

The system SHALL treat Telemost room creation or bootstrap prerequisites and
Telemost join or runtime-attach prerequisites as separate support boundaries.

#### Scenario: Room creation does not prove runtime readiness

- **GIVEN** the repository can create, fetch, or otherwise obtain a joinable
  Telemost room through an approved operator-owned surface
- **WHEN** the repository evaluates Telemost provider or runtime support
- **THEN** it treats that room-creation success as separate from room join or
  repo-owned same-device runtime-attach readiness
- **AND** it does not claim that one auth or bootstrap surface proves the
  others

### Requirement: Telemost support claims stay separate from `generic_turn`

The system SHALL not treat Telemost support, room URLs, or attachable room
artifacts as proof of `generic_turn` export or TURN-backed ready state unless a
separate transport-ready artifact exists.

#### Scenario: Telemost room artifact does not masquerade as TURN

- **GIVEN** a Telemost flow can produce a room URL, conference summary, or
  another conference-style artifact
- **WHEN** the repository reports the supported Telemost surface
- **THEN** it may describe Telemost as a conference-style provider path only
  through documented conference semantics
- **AND** it does not imply `generic_turn` export or TURN-backed ready state
  without a separate transport-ready artifact
