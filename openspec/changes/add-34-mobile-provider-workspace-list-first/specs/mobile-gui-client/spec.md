## ADDED Requirements
### Requirement: Mobile provider workspace is list-first

The system SHALL make saved managed provider records the primary content of the
top-level mobile `Providers` destination, with templates and full editing moved
into explicit create or detail flows.

#### Scenario: Operator opens Providers with saved records

- **GIVEN** the mobile shell has one or more saved managed provider records
- **WHEN** the operator opens the top-level `Providers` destination
- **THEN** the root surface shows those saved provider records as the primary
  list
- **AND** it provides a primary create action such as `New provider`
- **AND** it does not present the template catalog and the full editor as equal
  root sections before a record is chosen

#### Scenario: Operator opens Providers with no saved records

- **GIVEN** the mobile shell has no saved managed provider records
- **WHEN** the operator opens the top-level `Providers` destination
- **THEN** the root surface shows an empty state for saved providers
- **AND** it offers explicit actions to create a blank provider or browse
  templates
- **AND** the template catalog stays behind that explicit entry point instead of
  replacing the list-first root

#### Scenario: Operator uses a wider mobile layout

- **GIVEN** the mobile shell is running on a layout wide enough for simultaneous
  list and detail
- **WHEN** the operator selects a provider record from the root list
- **THEN** the shell may show provider detail or editor content beside the list
- **AND** the list of saved provider records remains the primary navigation
  spine

#### Scenario: Operator opens create or detail on a compact layout

- **GIVEN** the mobile shell is running on a compact layout
- **AND** the operator starts `New provider` or selects a saved provider record
- **WHEN** the shell opens provider detail or editor content
- **THEN** that detail or editor appears as a dedicated follow-on surface rather
  than as another peer section of the root `Providers` page
- **AND** dismissing or navigating back returns the operator to the saved-
  provider list-first root without making the template catalog the default root

## MODIFIED Requirements
### Requirement: Mobile GUI manages an app-owned provider workspace

The system SHALL let the mobile GUI create, edit, delete, and apply app-owned
managed provider records without depending on host-managed provider-config CRUD
as the primary reusable-provider workflow, while presenting provider families
as the operator-facing concept instead of exposing internal catalog jargon as
the main UI label or explanatory copy on operator-facing provider surfaces.

#### Scenario: Mobile shows provider families from the app

- **GIVEN** the shared app-owned provider catalog includes shipped supported
  providers such as `VK Calls` and `Generic TURN`
- **WHEN** the operator starts creating or editing a managed provider record on
  mobile
- **THEN** the shell lets them choose from those shipped provider families even
  if the connected mobile host does not advertise a reusable
  `provider_settings_schema`
- **AND** the UI shows current host availability as an overlay instead of
  removing the provider family from the workspace
- **AND** the operator-facing UI refers to that taxonomy as provider families
  or supported provider families rather than `App-owned provider catalog`
- **AND** it does not use `App-owned provider catalog` as the primary heading or
  explanatory copy of the create or edit surface

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

### Requirement: Mobile GUI offers curated preset bootstrap flows

The system SHALL provide mobile-first template bootstrap entry points that seed
managed provider drafts or records for the primary provider families without
turning the top-level `Providers` root into a preset catalog.

#### Scenario: Mobile starts a new provider from an available template

- **GIVEN** a mobile preset for a shipped supported provider family
- **WHEN** the operator starts the new-provider flow and chooses `Start from
  template`
- **THEN** the app shows the available templates and lets them seed a new
  managed provider draft or record for that provider family
- **AND** the template does not pretend to be a separate provider identity

#### Scenario: Mobile browses many templates

- **GIVEN** the mobile shell ships many provider templates
- **WHEN** the operator opens the template picker
- **THEN** the shell provides search or filtering by provider family so the
  template list remains navigable
- **AND** those templates stay inside the create flow instead of occupying the
  top-level `Providers` root

#### Scenario: Mobile keeps unavailable templates explicit

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the operator opens the mobile template picker
- **THEN** it does not show a template for that unsupported provider family
- **AND** it does not imply support through placeholder cards on the top-level
  `Providers` root
