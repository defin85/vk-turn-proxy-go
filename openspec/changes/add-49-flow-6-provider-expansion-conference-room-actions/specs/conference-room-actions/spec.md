## ADDED Requirements
### Requirement: Conference-room artifacts expose typed non-secret room summaries

The system SHALL expose `conference_room` artifacts through typed non-secret
summary fields instead of provider-specific raw payload parsing in shells.

#### Scenario: Ordinary resolution read exposes conference-room summary

- **GIVEN** a provider resolution succeeds with the `conference_room` artifact
  family
- **WHEN** a shell reads that resolution through the ordinary host contract
- **THEN** the artifact includes typed non-secret room summary fields and
  machine-readable action metadata
- **AND** the shell does not need provider-specific raw payload parsing to
  render the ordinary action surface

#### Scenario: Secret-bearing room material stays redacted

- **GIVEN** a `conference_room` artifact includes provider-owned room or media
  secrets internally
- **WHEN** the host returns ordinary reads, events, or persisted shell state
- **THEN** those secret-bearing fields remain redacted
- **AND** the ordinary action surface is built from non-secret summary fields
  only

### Requirement: Conference-room actions are explicit and fail-closed

The system SHALL expose conference-room post-resolution actions through stable
machine-readable identifiers and fail closed for unsupported execution paths.

#### Scenario: Conference-room artifact advertises open-room action

- **GIVEN** a resolved `conference_room` artifact
- **WHEN** the host reports the supported actions for that artifact
- **THEN** it advertises the stable `open_room` action when that navigation
  target is available
- **AND** the action metadata identifies that execution is shell-external
  rather than a fake local runtime session

#### Scenario: Same-device conference execution is unavailable

- **GIVEN** a resolved `conference_room` artifact and no committed local
  conference executor
- **WHEN** a caller asks for same-device execution
- **THEN** the host fails explicitly
- **AND** it does not create a fake runtime session
- **AND** it does not reinterpret the artifact as a `generic_turn` handoff

### Requirement: Desktop and mobile shells present conference-room actions without tunnel semantics

The system SHALL let desktop and mobile shells present the same conference-room
action surface without implying tunnel or local conference execution support.

#### Scenario: Operator opens a resolved conference room from the shell

- **GIVEN** a desktop or mobile shell reads a resolved `conference_room`
  artifact with the `open_room` action
- **WHEN** the operator invokes that action
- **THEN** the shell uses the typed navigation target supplied for the action
- **AND** it does not require provider-name-specific branching to decide the
  ordinary action behavior

#### Scenario: Shell does not present tunnel startup for conference-room artifacts

- **GIVEN** a resolved `conference_room` artifact
- **WHEN** the shell renders the ordinary post-resolution actions
- **THEN** it does not present tunnel startup, `generic-turn` export, or local
  conference execution as available actions
- **AND** unsupported actions remain fail-closed and explicit
