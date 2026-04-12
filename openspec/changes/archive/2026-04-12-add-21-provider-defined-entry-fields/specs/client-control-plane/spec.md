## ADDED Requirements
### Requirement: Client control plane accepts descriptor-declared provider settings

The system SHALL let providers declare reusable user-configurable settings as
part of the provider entry contract without requiring shell-specific hard-coded
fields.

#### Scenario: Shell starts resolution with validated provider settings

- **GIVEN** a provider descriptor that includes a `provider_settings_schema`
- **WHEN** a shell starts resolution for that provider
- **THEN** the request may include a `provider_settings` object in addition to
  the typed input envelope
- **AND** the host validates that object against the descriptor-declared schema
  before resolution begins
- **AND** the host rejects undeclared or invalid setting keys instead of
  ignoring them

### Requirement: Saved profiles keep only profile-retained provider settings

The system SHALL keep reusable provider settings separate from ephemeral
provider entry values and runtime defaults.

#### Scenario: Shell saves a profile with provider settings

- **GIVEN** a provider descriptor whose settings schema marks some fields as
  `profile` retained and others as `ephemeral`
- **WHEN** a shell upserts a saved profile
- **THEN** the profile contract stores only the `profile`-retained provider
  settings
- **AND** it does not persist `writeOnly` or `ephemeral` provider setting
  values as part of the saved profile

### Requirement: Invalid provider settings fail with field-aware errors

The system SHALL report provider-setting validation failures through typed
errors that identify the failing field and rule.

#### Scenario: Shell submits an invalid provider setting

- **GIVEN** a descriptor-declared provider settings schema
- **WHEN** a caller sends a missing, undeclared, or shape-invalid provider
  setting
- **THEN** the host returns an explicit validation failure
- **AND** the failure identifies the provider-setting key plus a stable
  violation code such as `required`, `unknown`, `type`, `enum`, or `pattern`
- **AND** the host does not silently coerce the invalid setting into a guessed
  value
