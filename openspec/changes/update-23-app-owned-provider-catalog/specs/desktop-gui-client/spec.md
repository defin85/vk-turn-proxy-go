## MODIFIED Requirements
### Requirement: Desktop GUI manages an app-owned provider workspace

The system SHALL let the desktop GUI create, edit, delete, and apply
app-owned managed provider records without depending on host-managed
provider-config CRUD as the primary reusable-provider workflow.

#### Scenario: Desktop shows the supported provider catalog from the app

- **GIVEN** the shared app-owned provider catalog includes shipped supported
  providers such as `VK Calls` and `Generic TURN`
- **WHEN** the operator opens the desktop provider workspace
- **THEN** the workspace lists those supported providers even if the current
  host does not advertise a reusable `provider_settings_schema`
- **AND** the UI shows current host availability as an overlay instead of
  making the provider disappear

#### Scenario: Desktop edits a managed provider record

- **GIVEN** a supported provider family in the app-owned catalog
- **WHEN** the operator creates or edits a managed provider record on desktop
- **THEN** the desktop shell stores that record in shell-owned state
- **AND** that record contains only reusable non-secret provider-owned values
- **AND** later profile drafts can apply it by snapshot copy
- **AND** editing the managed provider record does not silently mutate already
  saved profiles

#### Scenario: Desktop managed provider can have zero reusable fields

- **GIVEN** a shipped supported provider family whose first managed-provider
  slice exposes zero reusable provider-owned fields
- **WHEN** the operator views that provider in the desktop provider workspace
- **THEN** the desktop shell still lists it as a supported managed provider
- **AND** the UI does not invent placeholder editable fields just to fill the
  form

### Requirement: Desktop GUI offers presets as provider-record seeds

The system SHALL offer curated desktop presets as seed templates for new
managed provider records instead of as a second standalone provider taxonomy.

#### Scenario: Desktop preset seeds a managed provider draft

- **GIVEN** a desktop preset for a shipped supported provider family
- **WHEN** the operator chooses that preset on desktop
- **THEN** the GUI seeds a new managed provider draft or record for that
  provider family
- **AND** the preset does not pretend to be a separate provider identity

#### Scenario: Desktop does not show speculative provider presets

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the desktop shell renders its preset catalog
- **THEN** it does not show a preset for that unsupported provider family
- **AND** it does not imply support through placeholder cards

## ADDED Requirements
### Requirement: Desktop profile editor supports managed-provider and custom modes

The system SHALL let the desktop profile workspace start from either a managed
provider record or a custom provider path.

#### Scenario: Desktop profile uses a managed provider

- **GIVEN** an existing managed provider record in desktop shell state
- **WHEN** the operator selects that managed provider while editing a profile
- **THEN** the profile draft inherits the provider family and editable
  provider-owned settings by snapshot
- **AND** the operator can still edit profile-local runtime defaults

#### Scenario: Desktop reopens a saved managed-provider profile in managed mode

- **GIVEN** a saved desktop profile that was last edited from a managed
  provider record
- **WHEN** the operator reopens that profile in the desktop shell
- **THEN** the shell restores managed-provider mode for that profile workspace
- **AND** it does not silently reopen the profile as if it were an unrelated
  custom-provider draft

#### Scenario: Desktop profile uses a custom provider path

- **GIVEN** an operator who needs a raw provider entry path not backed by a
  managed provider record
- **WHEN** they switch the desktop profile workspace to custom provider mode
- **THEN** the editor accepts direct provider and input values
- **AND** prompt-only or session-scoped inputs remain profile-local instead of
  being persisted back into the managed-provider catalog
- **AND** that custom path does not mutate the managed-provider catalog
