## MODIFIED Requirements
### Requirement: Mobile GUI manages an app-owned provider workspace

The system SHALL let the mobile GUI create, edit, delete, and apply app-owned
managed provider records without depending on host-managed provider-config CRUD
as the primary reusable-provider workflow.

#### Scenario: Mobile shows the supported provider catalog from the app

- **GIVEN** the shared app-owned provider catalog includes shipped supported
  providers such as `VK Calls` and `Generic TURN`
- **WHEN** the operator opens the mobile provider workspace
- **THEN** the workspace lists those supported providers even if the connected
  mobile host does not advertise a reusable `provider_settings_schema`
- **AND** the UI shows current host availability as an overlay instead of
  removing the provider from the workspace

#### Scenario: Mobile edits a managed provider record

- **GIVEN** a supported provider family in the app-owned catalog
- **WHEN** the operator creates or edits a managed provider record on mobile
- **THEN** the mobile shell stores that record in shell-owned state
- **AND** that record contains only reusable non-secret provider-owned values
- **AND** later profile drafts can apply it by snapshot copy
- **AND** editing the managed provider record does not silently mutate already
  saved profiles

#### Scenario: Mobile managed provider can have zero reusable fields

- **GIVEN** a shipped supported provider family whose first managed-provider
  slice exposes zero reusable provider-owned fields
- **WHEN** the operator views that provider in the mobile provider workspace
- **THEN** the mobile shell still lists it as a supported managed provider
- **AND** the UI does not invent placeholder editable fields just to fill the
  form

### Requirement: Mobile GUI offers presets as provider-record seeds

The system SHALL offer mobile presets as seed templates for new managed
provider records instead of as a second standalone provider taxonomy.

#### Scenario: Mobile preset seeds a managed provider draft

- **GIVEN** a mobile preset for a shipped supported provider family
- **WHEN** the operator chooses that preset on mobile
- **THEN** the app seeds a new managed provider draft or record for that
  provider family
- **AND** the preset does not pretend to be a separate provider identity

#### Scenario: Mobile does not show speculative provider presets

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the mobile shell renders its preset catalog
- **THEN** it does not show a preset for that unsupported provider family
- **AND** it does not imply support through placeholder cards

## ADDED Requirements
### Requirement: Mobile profile editor supports managed-provider and custom modes

The system SHALL let the mobile profile workspace start from either a managed
provider record or a custom provider path.

#### Scenario: Mobile profile uses a managed provider

- **GIVEN** an existing managed provider record in mobile shell state
- **WHEN** the operator selects that managed provider while editing a profile
- **THEN** the profile draft inherits the provider family and editable
  provider-owned settings by snapshot
- **AND** the operator can still edit profile-local runtime defaults

#### Scenario: Mobile reopens a saved managed-provider profile in managed mode

- **GIVEN** a saved mobile profile that was last edited from a managed provider
  record
- **WHEN** the operator reopens that profile in the mobile shell
- **THEN** the shell restores managed-provider mode for that profile workspace
- **AND** it does not silently reopen the profile as if it were an unrelated
  custom-provider draft

#### Scenario: Mobile profile uses a custom provider path

- **GIVEN** an operator who needs a raw provider entry path not backed by a
  managed provider record
- **WHEN** they switch the mobile profile workspace to custom provider mode
- **THEN** the editor accepts direct provider and input values
- **AND** prompt-only or session-scoped inputs remain profile-local instead of
  being persisted back into the managed-provider catalog
- **AND** that custom path does not mutate the managed-provider catalog
