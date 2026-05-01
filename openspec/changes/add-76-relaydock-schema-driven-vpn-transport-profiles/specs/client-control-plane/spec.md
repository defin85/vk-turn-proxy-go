## ADDED Requirements

### Requirement: Control-plane clients preserve unknown transport profile metadata

The client control plane SHALL preserve host-advertised transport profile kind,
schema, and import-adapter metadata even when a shell build does not have a
compile-time case for that concrete kind.

#### Scenario: Unknown profile kind is reported

- **GIVEN** a host includes a transport profile kind unknown to the shell build
- **WHEN** the shell negotiates host capabilities or reads profile status
- **THEN** the client model keeps the raw kind value available for display,
  setup decisions, diagnostics, and fail-closed validation
- **AND** it does not coerce that value to `wireguard_native_v1`
- **AND** it does not drop unrelated platform tunnel or profile-store
  capability data from the same response

#### Scenario: Unknown import adapter is reported

- **GIVEN** a host advertises an import adapter unknown to the shell build
- **WHEN** the shell evaluates profile setup actions
- **THEN** the client model preserves the adapter id, target profile kind, and
  display metadata
- **AND** the shell uses the adapter only when the host advertises the adapter
  for the required kind
- **AND** the shell executes the adapter only when it supports the advertised
  material acquisition method
- **AND** otherwise startup and import fail closed with an explicit unsupported
  action

### Requirement: Structured save payloads follow advertised schemas

The client control plane SHALL build structured create, update, validation, and
key-generation requests from the advertised profile-kind schema instead of from
WireGuard-specific request shapes.

#### Scenario: Shell saves a schema-rendered profile

- **GIVEN** a host advertises structured create or update for a profile kind
- **AND** the shell renders the editor from that schema
- **WHEN** the operator saves the draft
- **THEN** the client sends the profile kind, schema version, a field-value map
  keyed by stable field ids, and an explicit secret-action map required by that
  schema
- **AND** it does not include fields that the schema did not advertise as
  supported
- **AND** non-WireGuard kinds are not serialized through WireGuard-shaped draft
  fields
- **AND** it clears submitted secret field values from shell memory after the
  request completes or fails

#### Scenario: Shell receives untrusted presentation metadata

- **GIVEN** a host schema includes labels, helper text, grouping hints, or
  validation messages
- **WHEN** a shell renders those values
- **THEN** it treats them as inert display text
- **AND** it does not execute host-provided links, markup, commands, or scripts
- **AND** host-provided presentation metadata does not replace host-side
  validation authority
