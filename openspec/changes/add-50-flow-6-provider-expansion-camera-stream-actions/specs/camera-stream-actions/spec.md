## ADDED Requirements
### Requirement: Camera-stream artifacts expose typed non-secret camera summaries

The system SHALL expose `camera_stream` artifacts through typed non-secret
summary fields instead of provider-specific raw payload parsing in shells.

#### Scenario: Ordinary resolution read exposes camera-stream summary

- **GIVEN** a provider resolution succeeds with the `camera_stream` artifact
  family
- **WHEN** a shell reads that resolution through the ordinary host contract
- **THEN** the artifact includes typed non-secret camera summary fields and
  machine-readable action metadata
- **AND** the shell does not need provider-specific raw payload parsing to
  render the ordinary action surface

#### Scenario: Secret-bearing player material stays redacted

- **GIVEN** a `camera_stream` artifact includes provider-owned stream, player,
  or archive tokens internally
- **WHEN** the host returns ordinary reads, events, or persisted shell state
- **THEN** those secret-bearing fields remain redacted
- **AND** the ordinary action surface is built from non-secret summary fields
  only

### Requirement: Camera-stream actions are explicit and fail-closed

The system SHALL expose camera-stream post-resolution actions through stable
machine-readable identifiers and fail closed for unsupported execution paths.

#### Scenario: Camera-stream artifact advertises open-camera action

- **GIVEN** a resolved `camera_stream` artifact
- **WHEN** the host reports the supported actions for that artifact
- **THEN** it advertises the stable `open_camera` action when that navigation
  target is available
- **AND** the action metadata identifies that execution is shell-external
  rather than a fake local runtime or player session

#### Scenario: Camera-stream artifact advertises optional archive action

- **GIVEN** a resolved `camera_stream` artifact that exposes archive access
- **WHEN** the host reports the supported actions for that artifact
- **THEN** it may advertise the stable `open_archive` action with a typed
  non-secret navigation target
- **AND** the shell does not infer archive support from provider-specific raw
  payloads

#### Scenario: Same-device camera playback is unavailable

- **GIVEN** a resolved `camera_stream` artifact and no committed local media
  executor
- **WHEN** a caller asks for same-device playback
- **THEN** the host fails explicitly
- **AND** it does not create a fake runtime session
- **AND** it does not reinterpret the artifact as a conference room or tunnel
  handoff

#### Scenario: Provider-owned player transport evidence does not imply local execution

- **GIVEN** a resolved `camera_stream` artifact whose provider research
  reveals concrete browser or native player transport details
- **WHEN** no family-specific same-device executor has been committed and
  live-verified for that artifact family
- **THEN** the host continues to advertise only the navigation-first
  camera-stream actions that are already committed for that artifact
- **AND** it does not treat those provider-owned transport details as
  permission to expose same-device playback, transport export, or tunnel
  startup

### Requirement: Desktop and mobile shells present camera-stream actions without false playback claims

The system SHALL let desktop and mobile shells present the same camera-stream
action surface without implying conference, tunnel, or local playback support.

#### Scenario: Operator opens a resolved camera stream from the shell

- **GIVEN** a desktop or mobile shell reads a resolved `camera_stream`
  artifact with the `open_camera` action
- **WHEN** the operator invokes that action
- **THEN** the shell uses the typed navigation target supplied for the action
- **AND** it does not require provider-name-specific branching to decide the
  ordinary action behavior

#### Scenario: Shell does not present tunnel or conference actions for camera streams

- **GIVEN** a resolved `camera_stream` artifact
- **WHEN** the shell renders the ordinary post-resolution actions
- **THEN** it does not present tunnel startup, `open_room`, or fake local
  playback as available actions
- **AND** unsupported actions remain fail-closed and explicit
