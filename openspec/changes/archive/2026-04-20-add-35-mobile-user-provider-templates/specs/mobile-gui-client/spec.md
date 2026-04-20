## MODIFIED Requirements
### Requirement: Mobile GUI manages an app-owned provider workspace

The system SHALL let the mobile GUI create, edit, delete, and apply shell-owned
managed provider records without depending on host-managed provider-config CRUD
as the primary reusable-provider workflow, while keeping provider families as a
shipped app-owned taxonomy rather than a user-editable entity.

#### Scenario: Mobile shows provider families from the app

- **GIVEN** the shared app-owned provider catalog includes shipped supported
  provider families such as `VK Calls` and `Generic TURN`
- **WHEN** the operator opens the mobile provider workspace or starts a new
  provider or template flow
- **THEN** the shell lets them choose from those shipped provider families even
  if the connected mobile host does not advertise a reusable
  `provider_settings_schema`
- **AND** the UI shows current host availability as an overlay instead of
  removing the provider family from the workspace
- **AND** the operator cannot create, rename, or delete provider families from
  the mobile shell

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
- **WHEN** the operator views that provider family in the mobile provider
  workspace
- **THEN** the mobile shell still lists it as a supported managed provider
  family
- **AND** the UI does not invent placeholder editable fields just to fill the
  form

### Requirement: Mobile GUI manages shell-owned user provider templates

The system SHALL let the mobile GUI create, edit, delete, and use shell-owned
user provider templates that store reusable non-secret provider-owned values
and seed new managed provider drafts without becoming provider families or
saved managed provider records themselves.

#### Scenario: Operator saves a user template from provider work

- **GIVEN** the operator is editing a managed provider draft or saved managed
  provider record on mobile
- **WHEN** they choose `Save as template`
- **THEN** the shell opens a user-template editing flow prefilled from the
  current provider family and reusable settings
- **AND** saving stores a new user template in shell-owned local state
- **AND** prompt-only or secret provider values are not persisted into that
  template

#### Scenario: Operator edits or deletes a user template

- **GIVEN** a saved shell-owned user template
- **WHEN** the operator updates or deletes that template in the mobile shell
- **THEN** the change applies only to that template entry
- **AND** it does not silently mutate saved managed providers or saved profiles
  that were created earlier

#### Scenario: Operator uses a user template

- **GIVEN** a saved shell-owned user template
- **WHEN** the operator chooses `Use template`
- **THEN** the mobile shell seeds a new managed provider draft for that
  provider family by snapshot copy
- **AND** later edits to the template do not mutate that seeded draft

## MODIFIED Requirements
### Requirement: Mobile GUI offers curated preset bootstrap flows

The system SHALL provide mobile-first template bootstrap entry points that
combine read-only shipped templates with shell-owned user templates, while
keeping the top-level `Providers` destination focused on saved providers rather
than a template catalog.

#### Scenario: Mobile distinguishes user templates from shipped templates

- **GIVEN** the mobile shell has one or more user templates and one or more
  shipped templates
- **WHEN** the operator opens the template picker from the new-provider flow
- **THEN** the UI keeps `My templates` distinct from shipped templates
- **AND** search or filtering does not erase that distinction

#### Scenario: Mobile keeps shipped templates read-only

- **GIVEN** a shipped template in the mobile template picker
- **WHEN** the operator inspects it
- **THEN** the shell allows using that template as a seed
- **AND** it does not offer edit or delete actions for that shipped template

#### Scenario: Mobile keeps unavailable shipped templates explicit

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the operator opens the mobile template picker
- **THEN** it does not show a shipped template for that unsupported provider
  family
- **AND** it does not imply support through placeholder template cards
