# provider-runtime-artifacts Specification

## Purpose
TBD - created by archiving change add-20-multi-provider-runtime-families. Update Purpose after archive.
## Requirements
### Requirement: Provider catalog exposes runtime-aware descriptors

The system SHALL expose typed provider descriptors so shells can discover
provider-specific entry constraints without hard-coding workflow logic to
provider identifiers.

#### Scenario: Shell discovers provider descriptors before data entry

- **GIVEN** a compatible host with one or more supported providers
- **WHEN** a shell requests the provider catalog
- **THEN** the host returns stable descriptors for each provider
- **AND** each descriptor includes the provider identifier, display metadata,
  expected input kind, auth posture, browser policy, potential challenge modes,
  artifact families, and capability hints needed for shell UX
- **AND** the shell does not need to infer workflow solely from the provider
  string

#### Scenario: Provider requires account auth or an external browser

- **GIVEN** a provider whose real entry flow depends on authenticated account
  state, anti-bot constraints, or a browser surface outside an embedded WebView
- **WHEN** a shell reads that provider descriptor
- **THEN** the host reports those auth and browser constraints explicitly
- **AND** the shell does not silently assume that a guest-only or embedded
  browser flow is valid

### Requirement: Successful resolution yields a typed artifact family

The system SHALL represent successful provider resolution as a typed artifact
family rather than assuming that every provider result can be flattened into a
`generic-turn` handoff.

#### Scenario: Generic TURN artifact resolves successfully

- **GIVEN** a provider resolution that yields transport-ready TURN credentials
- **WHEN** the resolution reaches `resolved`
- **THEN** the record identifies the artifact family as `generic_turn`
- **AND** the host may report same-device startup and explicit export
  capabilities when the family contract and expiry evidence allow them

#### Scenario: Conference-room artifact resolves successfully

- **GIVEN** a provider resolution that yields room-scoped conference access
  rather than transport-ready TURN credentials
- **WHEN** the resolution reaches `resolved`
- **THEN** the record identifies the artifact family as `conference_room`
- **AND** the host reports only the actions that are valid for that family
- **AND** the host does not claim `generic-turn` export unless a separate
  transport-ready artifact also exists

#### Scenario: Camera-stream artifact resolves successfully

- **GIVEN** a provider resolution that yields camera or player access rather
  than conference-room or TURN handoff semantics
- **WHEN** the resolution reaches `resolved`
- **THEN** the record identifies the artifact family as `camera_stream`
- **AND** the host reports only camera/player actions that are valid for that
  family
- **AND** it does not pretend that the result is a conference room or a tunnel
  handoff

### Requirement: Artifact actions are explicit and capability-gated

The system SHALL expose post-resolution actions through explicit
capability-gated contracts per artifact family.

#### Scenario: Unsupported export fails closed

- **GIVEN** a resolved artifact family that does not support explicit
  cross-device handoff export
- **WHEN** a caller requests export
- **THEN** the host fails explicitly
- **AND** it does not synthesize a guessed `generic-turn` or equivalent secret
  handoff

#### Scenario: Supported actions use stable identifiers

- **GIVEN** a resolved artifact family with one or more post-resolution actions
- **WHEN** the host returns the supported action set for that artifact
- **THEN** each action is represented by a stable machine-readable identifier
  rather than by a display-only label
- **AND** desktop and mobile shells can map that identifier into
  platform-specific copy or affordances without reintroducing provider-name
  branching

#### Scenario: Supported actions report execution ownership

- **GIVEN** a resolved artifact family with supported post-resolution actions
- **WHEN** the host returns action metadata for that artifact
- **THEN** the metadata identifies whether each action is executed by the host,
  by a shell-local adapter, or by a shell-external navigation handoff
- **AND** shells do not guess that ownership from provider-specific heuristics
  or from the display label

#### Scenario: Shell-external actions expose typed non-secret targets

- **GIVEN** a resolved artifact family with one or more `shell_external`
  actions such as `open_room`, `open_camera`, or `open_archive`
- **WHEN** the host returns ordinary resolution reads or resolution events for
  that artifact
- **THEN** the artifact summary includes typed non-secret navigation target
  fields for the advertised family actions
- **AND** shells do not recover those targets from provider-specific raw
  artifacts or secret-bearing diagnostics

#### Scenario: Same-device execution requires a family-specific executor

- **GIVEN** a resolved artifact family and a requested same-device action
- **WHEN** the current host build lacks a family-specific executor for that
  action
- **THEN** the host fails explicitly
- **AND** it does not create a fake runtime session
- **AND** it does not report the artifact as locally executable

#### Scenario: Provider-required browser surface is unavailable

- **GIVEN** a provider or action that requires an external browser or another
  specific continuation surface
- **WHEN** the current shell or host build cannot provide that surface
- **THEN** the host or shell fails explicitly
- **AND** it does not silently downgrade the flow to an unsupported embedded
  browser path

### Requirement: Ordinary reads stay redacted across artifact families

The system SHALL keep secret-bearing provider artifacts redacted in ordinary
reads, events, diagnostics, and persisted shell state regardless of artifact
family.

#### Scenario: Secret-bearing conference or camera tokens remain redacted

- **GIVEN** a resolved artifact family that uses room tokens, chat tokens,
  stream tokens, cookie/bootstrap tokens, or other provider secrets
- **WHEN** a shell lists resolutions, reads one resolution, consumes host
  events, or exports diagnostics without an explicit export action
- **THEN** the host returns only redacted or non-secret summary fields
- **AND** raw provider tokens do not appear in ordinary state reads

### Requirement: Provider descriptors may declare reusable settings schemas

The system SHALL let a provider descriptor advertise provider-defined,
user-configurable entry settings independently from runtime defaults.

#### Scenario: Shell discovers provider settings before data entry

- **GIVEN** a provider with one or more user-configurable entry settings
- **WHEN** a shell requests the provider catalog
- **THEN** the descriptor may include a `provider_settings_schema`
- **AND** that schema declares stable machine-readable setting keys plus the
  labels, validation rules, and persistence hints needed for generic shell UX
- **AND** the shell does not need provider-name-specific code to discover those
  settings

### Requirement: Provider settings schema uses a constrained portable subset

The system SHALL keep provider settings portable across host and shell
implementations by constraining the schema surface.

#### Scenario: Host advertises a provider settings schema

- **GIVEN** a provider descriptor with `provider_settings_schema`
- **WHEN** a host serializes that descriptor
- **THEN** the schema root is an object with `additionalProperties: false`
- **AND** the portable field subset is limited to scalar properties, enums, and
  basic validation or annotation keywords needed for generic shell rendering
- **AND** repo-specific rendering or persistence hints are exposed through
  explicit `x-vkturn-*` extensions instead of provider-name branching

### Requirement: Descriptor-declared prompt-only values stay explicit

The system SHALL let descriptors mark prompt-only or write-only values without
pretending they are ordinary reusable profile settings.

#### Scenario: Descriptor marks a write-only ephemeral setting

- **GIVEN** a provider setting property with `writeOnly: true`
- **AND** that property is marked with `x-vkturn-persistence: ephemeral`
- **WHEN** a shell consumes the descriptor
- **THEN** the shell can render it as prompt-only input
- **AND** ordinary saved-profile flows do not require that value to be echoed
  back from the host as plaintext profile metadata

