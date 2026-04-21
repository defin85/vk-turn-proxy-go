## ADDED Requirements
### Requirement: Telemost descriptor exposes explicit entry posture

The system SHALL expose `yandex-telemost` through a typed provider descriptor
that makes its reviewed entry posture explicit.

#### Scenario: Shell reads the Telemost descriptor before data entry

- **GIVEN** a compatible host that includes a reviewed `yandex-telemost`
  provider contract
- **WHEN** a shell requests the provider catalog
- **THEN** the Telemost descriptor includes the provider identifier, input
  kind, auth posture, browser policy, possible challenge modes, and the
  reviewed artifact families for that provider
- **AND** the shell does not infer the Telemost workflow from the provider
  identifier alone

#### Scenario: Telemost descriptor does not imply unreviewed entry modes

- **GIVEN** a reviewed `yandex-telemost` descriptor
- **WHEN** the descriptor does not explicitly authorize one entry mode such as
  guest-only, embedded-browser, or same-device attach
- **THEN** the shell keeps that entry mode unavailable
- **AND** it does not guess support from historical behavior or provider-name
  conventions

### Requirement: Successful Telemost resolution yields a conference-room artifact

The system SHALL model successful `yandex-telemost` resolution as a
`conference_room` artifact plus the committed conference-room action surface.

#### Scenario: Telemost room resolves successfully

- **GIVEN** a reviewed Telemost provider flow reaches a successful resolved
  state
- **WHEN** the host returns the ordinary resolution record
- **THEN** the record identifies the artifact family as `conference_room`
- **AND** the ordinary action surface may advertise `open_room`
- **AND** the host does not reinterpret the Telemost result as
  `generic_turn`

#### Scenario: Telemost ordinary reads stay redacted

- **GIVEN** a successful Telemost resolution uses provider-owned room or
  bootstrap secrets internally
- **WHEN** the shell reads ordinary resolution state, events, or diagnostics
- **THEN** those secret-bearing details remain redacted
- **AND** the ordinary artifact summary exposes only non-secret room and action
  metadata

### Requirement: Same-device Telemost attach stays separately gated

The system SHALL keep same-device Telemost attach or runtime execution behind a
separate approved carrier contract.

#### Scenario: Telemost provider exists without same-device carrier support

- **GIVEN** a host build exposes the reviewed `yandex-telemost` provider
- **AND** no approved Telemost same-device carrier is packaged and verified
- **WHEN** a shell renders the ordinary post-resolution actions
- **THEN** it may present the documented shell-external room action surface
- **AND** it does not present same-device Telemost execution as available
