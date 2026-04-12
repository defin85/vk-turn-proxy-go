## ADDED Requirements
### Requirement: Client control plane manages reusable provider configs

The system SHALL expose reusable provider-config records for descriptor-retained
non-secret provider settings independently from saved runtime profiles.

#### Scenario: Shell creates a provider config

- **GIVEN** a provider descriptor that includes a supported
  `provider_settings_schema`
- **WHEN** a shell creates a provider config for that provider
- **THEN** the control plane stores a named provider-config record with only
  descriptor-retained provider settings
- **AND** the shell can later list, edit, or delete that record without
  editing a saved runtime profile

#### Scenario: Control plane rejects prompt-only settings in a provider config

- **GIVEN** a provider settings schema that marks one or more fields as
  `writeOnly` or `ephemeral`
- **WHEN** a caller tries to persist those fields through provider-config CRUD
- **THEN** the control plane rejects the request explicitly
- **AND** it does not silently store prompt-only or secret-like values as a
  reusable provider config

### Requirement: Provider-config validation stays descriptor-driven

The system SHALL validate provider-config records against the currently
advertised provider descriptor instead of shell-local heuristics.

#### Scenario: Caller submits undeclared or now-invalid provider settings

- **GIVEN** a provider config create or update request
- **WHEN** the request includes undeclared keys, type-invalid values, or values
  that no longer satisfy the current descriptor schema
- **THEN** the control plane rejects the request with a typed field-aware
  validation failure
- **AND** it does not coerce invalid settings into guessed defaults

#### Scenario: Stored provider config becomes unavailable

- **GIVEN** a previously valid provider config
- **AND** the host no longer advertises that provider or no longer supports the
  stored schema shape
- **WHEN** a shell lists provider configs
- **THEN** the control plane keeps the record explicit as unavailable or
  incompatible metadata
- **AND** shells can block apply/edit flows honestly instead of silently
  guessing compatibility

### Requirement: Profile apply from a provider config is snapshot-based

The system SHALL keep saved profiles self-contained when a shell applies a
provider config.

#### Scenario: Shell applies a provider config before saving a profile

- **GIVEN** a reusable provider config for one provider
- **WHEN** a shell applies that config to an active profile draft and saves the
  resulting profile
- **THEN** the saved profile stores its own provider-settings snapshot
- **AND** later edits to the original provider config do not silently mutate
  the saved profile
