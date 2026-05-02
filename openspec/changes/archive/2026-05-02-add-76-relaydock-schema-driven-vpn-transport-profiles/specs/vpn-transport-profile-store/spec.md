## ADDED Requirements

### Requirement: Transport profile kinds are host-advertised and extensible

The VPN transport profile store SHALL treat profile kind values as
host-advertised capability data rather than as a WireGuard-only closed product
surface.

#### Scenario: Host advertises a future profile kind

- **GIVEN** a profile-store-capable host advertises an editable kind other than
  `wireguard_native_v1`
- **WHEN** a shell reads the transport profile store capability
- **THEN** the shell preserves the raw kind value and associated schema
  metadata
- **AND** it does not reject the entire host capability response only because
  the kind is unknown to the shell build
- **AND** it does not treat that kind as startable unless a compatible runtime
  execution plan and host adapter evidence are also advertised

#### Scenario: Unknown kind has no compatible runtime plan

- **GIVEN** a host advertises a transport profile kind that the shell can
  display from schema metadata
- **AND** no runtime execution plan declares that kind as a supported
  prerequisite
- **WHEN** the operator views setup state
- **THEN** the shell may show the profile kind as configurable or unsupported
  setup metadata
- **AND** VPN startup remains disabled with an explicit unavailable or
  setup-needed reason

### Requirement: Structured profile schemas are transport-neutral

The VPN transport profile store SHALL describe structured editable fields using
transport-neutral descriptors so shells can render profile editors without
hard-coding WireGuard fields.

#### Scenario: Host advertises a non-WireGuard structured schema

- **GIVEN** a host supports structured editing for a non-WireGuard profile kind
- **WHEN** it reports the editable schema
- **THEN** the schema lists stable field ids, value kinds, cardinality,
  required state, secret state, lifecycle actions, generation support, and
  update-preservation support for that kind
- **AND** the shell submits a field-value map and secret-action map keyed by
  those stable field ids
- **AND** unsupported or unknown submitted fields fail validation instead of
  being silently stored or ignored
- **AND** the host validates the resulting profile according to that kind's
  semantics before it becomes selectable for startup

#### Scenario: WireGuard schema remains one concrete schema

- **GIVEN** the host advertises `wireguard_native_v1`
- **WHEN** the shell renders its structured editor
- **THEN** WireGuard fields are rendered from the same schema descriptor
  mechanism as later profile kinds
- **AND** `.conf` import remains a WireGuard-specific import adapter rather
  than a generic VPN profile import path

#### Scenario: Schema uses unsupported value kind

- **GIVEN** a host schema contains a field value kind unsupported by the shell
  renderer
- **WHEN** the operator opens the profile setup surface
- **THEN** the shell reports structured editing as unsupported for that profile
  kind or field
- **AND** it offers only host-advertised fallback lifecycle actions that it can
  execute
- **AND** it does not submit partial, guessed, or defaulted values for the
  unsupported field

### Requirement: Multiple transport profiles remain explicitly selectable

The VPN transport profile store SHALL support multiple profile records without
turning kind, import history, or most-recent edit state into an implicit startup
selection.

#### Scenario: Host lists multiple compatible profiles

- **GIVEN** a host stores more than one VPN transport profile compatible with a
  selected execution plan
- **WHEN** the shell reads profile-store status
- **THEN** the host reports each profile with a stable profile id, kind,
  redacted validation status, compatibility status, and lifecycle actions
- **AND** startup uses only an explicit selected profile reference or
  host-reported scoped default binding
- **AND** the host does not infer startup selection from the last edited,
  imported, or displayed profile

#### Scenario: Operator selects profile for startup

- **GIVEN** multiple compatible transport profiles exist for one required kind
- **WHEN** the operator chooses one profile for startup or scoped default use
- **THEN** the shell invokes the host-advertised selection lifecycle action
- **AND** subsequent startup references the selected profile id
- **AND** incompatible profiles remain visible as status records but cannot be
  selected for that execution plan
