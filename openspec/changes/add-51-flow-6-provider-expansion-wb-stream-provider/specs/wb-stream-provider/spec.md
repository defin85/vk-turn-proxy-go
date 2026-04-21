## ADDED Requirements
### Requirement: WB Stream descriptor is explicitly gated by the committed rollout

The system SHALL advertise the `wb-stream` provider descriptor only when the
committed flow-6 shipping gate and conference-room action surface are ready for
that provider family.

#### Scenario: WB Stream is still unshipped

- **GIVEN** the repository has not yet satisfied the committed flow-6 rollout
  gate for `wb-stream`
- **WHEN** a shell reads the ordinary shipped provider catalog
- **THEN** the product does not advertise `wb-stream` as shipped support
- **AND** archived research, presets, or test-only traces do not override that
  fail-closed state

#### Scenario: WB Stream is promoted into shipped support

- **GIVEN** the repository has satisfied the committed flow-6 rollout gate for
  `wb-stream`
- **WHEN** a compatible shell reads the provider descriptor for that family
- **THEN** the host advertises a stable `wb-stream` descriptor
- **AND** the descriptor exposes the committed auth, browser, and input
  constraints for that provider family

### Requirement: WB Stream entry posture is explicit

The system SHALL keep WB-specific auth and browser posture explicit in the
descriptor and fail closed when the required surface is unavailable.

#### Scenario: WB Stream requires a specific browser posture

- **GIVEN** the committed WB flow requires one specific browser posture such as
  external-browser continuation
- **WHEN** a shell evaluates the `wb-stream` descriptor
- **THEN** the descriptor states that committed browser posture explicitly
- **AND** the shell does not silently downgrade the flow to another browser
  surface by guesswork

#### Scenario: WB Stream auth posture is provider-declared

- **GIVEN** the committed WB flow supports one or more specific auth postures
- **WHEN** a shell evaluates the `wb-stream` descriptor
- **THEN** the descriptor states the committed auth posture explicitly
- **AND** the shell does not guess whether guest or account-backed entry is
  valid from provider-name heuristics alone

### Requirement: Successful WB resolution yields a conference-room artifact

The system SHALL map successful `wb-stream` resolution to the committed
`conference_room` artifact family and its action surface.

#### Scenario: WB resolution succeeds

- **GIVEN** a `wb-stream` provider flow reaches its committed resolved state
- **WHEN** the host returns the ordinary resolution record
- **THEN** the record identifies the artifact family as `conference_room`
- **AND** it exposes the committed conference-room action surface such as
  `open_room`
- **AND** it does not claim `generic_turn` export or local conference execution

#### Scenario: WB resolution does not reach a committed conference-room result

- **GIVEN** a `wb-stream` flow fails to produce the committed conference-room
  result
- **WHEN** the host finalizes that resolution attempt
- **THEN** the attempt fails explicitly
- **AND** it does not synthesize a fake `conference_room` or `generic_turn`
  artifact

### Requirement: WB ordinary reads stay redacted and fail closed

The system SHALL keep WB-specific room or media secrets redacted in ordinary
reads and fail closed for blocked or incomplete provider flows.

#### Scenario: WB ordinary reads remain redacted

- **GIVEN** a resolved `wb-stream` artifact uses provider-owned room, media, or
  bootstrap secrets internally
- **WHEN** the host returns ordinary reads, events, or persisted shell state
- **THEN** those secret-bearing fields remain redacted
- **AND** only the non-secret conference-room summary and action surface are
  exposed

#### Scenario: WB flow is blocked or incomplete

- **GIVEN** a `wb-stream` flow is blocked by provider behavior, missing
  continuation state, or an unsupported browser posture
- **WHEN** the host cannot reach the committed resolved state
- **THEN** the attempt fails explicitly
- **AND** the product does not claim partial success from incomplete provider
  state alone
