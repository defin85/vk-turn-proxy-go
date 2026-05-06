## ADDED Requirements
### Requirement: WB Stream descriptor is explicitly gated by the committed rollout

The system SHALL advertise the `wb-stream` provider descriptor for
`https://stream.wb.ru/` only when the committed flow-6 shipping gate and
conference-room action surface are ready for that provider family.

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
- **AND** the descriptor does not imply same-device media execution or
  `generic-turn` export

### Requirement: WB Stream entry posture is explicit

The system SHALL keep WB-specific auth and browser posture explicit in the
descriptor and fail closed when the required surface is unavailable.

#### Scenario: WB Stream requires external browser or app handoff

- **GIVEN** the committed WB flow targets the public `https://stream.wb.ru/`
  web surface or a native WB Stream app handoff
- **WHEN** a shell evaluates the `wb-stream` descriptor
- **THEN** the descriptor states that external browser or app handoff is the
  committed browser posture
- **AND** the shell does not silently downgrade the flow to another browser
  surface by guesswork
- **AND** embedded-browser or headless execution is not presented as supported
  unless a later provider-approved change adds it explicitly

#### Scenario: WB Stream auth posture is provider-declared

- **GIVEN** WB Stream may allow guest entry or account-backed authorization by
  nickname or phone according to the provider-owned service surface
- **WHEN** a shell evaluates the `wb-stream` descriptor
- **THEN** the descriptor states the committed auth posture as
  `guest_or_account`
- **AND** the shell does not guess whether guest or account-backed entry is
  valid from provider-name heuristics alone

#### Scenario: WB Stream anti-bot boundary is not a parser target

- **GIVEN** unauthenticated HTTP access to the WB Stream web entrypoint returns
  a provider-owned challenge, anti-bot, or JavaScript-required boundary
- **WHEN** the repository evaluates resolver support
- **THEN** the provider remains fail-closed unless the committed flow has
  operator-provided input or provider-approved browser evidence
- **AND** the host does not bypass anti-bot controls or infer a hidden API
  contract from challenge pages

### Requirement: Successful WB resolution yields a conference-room artifact

The system SHALL map successful `wb-stream` resolution to the committed
`conference_room` artifact family and its action surface.

#### Scenario: WB room-link resolution succeeds

- **GIVEN** a `wb-stream` provider flow receives a supported non-secret
  `https://stream.wb.ru/` room or meeting URL
- **WHEN** the host returns the ordinary resolution record
- **THEN** the record identifies the artifact family as `conference_room`
- **AND** it exposes the committed conference-room action surface such as
  `open_room`
- **AND** it does not claim `generic_turn` export or local conference execution
- **AND** the `open_room` target is typed as shell-external navigation

#### Scenario: WB resolution does not reach a committed conference-room result

- **GIVEN** a `wb-stream` flow has a malformed URL, unsupported host, blocked
  auth state, missing external-browser support, or an incomplete provider result
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
- **AND** token-bearing or password-bearing room URL components are redacted
  unless the operator invokes an explicit action that is allowed to reveal them

#### Scenario: WB flow is blocked or incomplete

- **GIVEN** a `wb-stream` flow is blocked by provider behavior, missing
  continuation state, or an unsupported browser posture
- **WHEN** the host cannot reach the committed resolved state
- **THEN** the attempt fails explicitly
- **AND** the product does not claim partial success from incomplete provider
  state alone

#### Scenario: WB Stream commercial or account automation is out of scope

- **GIVEN** a proposed WB Stream workflow would automate account creation,
  recording export, commercial redistribution, or another provider-owned action
  beyond external room opening
- **WHEN** the repository evaluates the first `wb-stream` provider slice
- **THEN** that workflow remains unsupported
- **AND** it requires a later explicit change with legal, authorization,
  redaction, and live-evidence boundaries before it can be promoted
