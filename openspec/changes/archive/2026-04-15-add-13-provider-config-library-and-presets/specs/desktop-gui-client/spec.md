## ADDED Requirements
### Requirement: Desktop GUI manages a provider-config library

The system SHALL let the desktop GUI add, edit, delete, and apply reusable
provider configs without mixing them into runtime-default editing.

#### Scenario: Desktop operator edits reusable provider settings

- **GIVEN** a desktop GUI connected to a compatible host
- **AND** the host advertises a provider descriptor with a supported settings
  schema
- **WHEN** the operator opens the provider-config surface
- **THEN** the GUI renders schema-driven provider fields for add/edit/delete
  flows
- **AND** it keeps provider-config editing visually separate from runtime
  defaults and profile-input editing

#### Scenario: Desktop blocks apply for an unavailable provider config

- **GIVEN** a stored provider config whose provider descriptor is unavailable or
  incompatible on the connected host
- **WHEN** the operator views that config on desktop
- **THEN** the GUI marks it as unavailable
- **AND** it blocks apply/startup actions instead of silently mapping it to a
  different provider shape

### Requirement: Desktop GUI offers preset profile bootstrap cards

The system SHALL offer curated desktop preset entry points for the primary
provider families while staying honest about current host support.

#### Scenario: Desktop bootstrap uses an available preset

- **GIVEN** the connected host advertises the provider descriptor targeted by
  one of the preset cards
- **WHEN** the operator chooses the `VK`, `WB Stream`, or `RTK Smarthome`
  preset on desktop
- **THEN** the GUI seeds a new draft with that preset's provider family and
  curated defaults
- **AND** the operator can continue by applying or creating a provider config
  before saving or starting a profile

#### Scenario: Desktop shows a disabled preset for an unavailable provider

- **GIVEN** a preset whose target provider is not advertised by the connected
  host
- **WHEN** the operator views the preset catalog on desktop
- **THEN** the preset remains visible with explicit unavailable copy
- **AND** the GUI does not silently create a fake draft for that provider
