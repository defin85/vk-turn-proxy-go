## ADDED Requirements
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
