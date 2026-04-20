## ADDED Requirements

### Requirement: Mobile GUI exposes first-class root actions for profiles

The system SHALL expose profile management and portable-profile transfer actions
from the primary `Profiles` workflow surface instead of hiding them behind
profile creation or editor-only disclosure.

#### Scenario: Profiles root exposes import and export directly

- **GIVEN** the operator is on the mobile `Profiles` workflow root
- **WHEN** they need to import a profile or export a saved profile
- **THEN** the shell exposes explicit root-level profile import and saved-profile
  export actions from that `Profiles` surface
- **AND** importing a profile does not require opening `Add profile` first
- **AND** exporting a profile does not require navigating into the profile
  editor footer or disclosure sections first

#### Scenario: Profiles root exposes record actions for the focused profile

- **GIVEN** a focused saved profile on the `Profiles` workflow surface
- **WHEN** the operator inspects that root entity surface
- **THEN** the shell exposes a selection-aware root action row for `Edit`,
  `Copy`, `Delete`, and `Make current`
- **AND** those actions are discoverable without forcing the operator to hunt
  through editor-only overflow menus
- **AND** the shell does not duplicate that same record-action cluster in a
  second detail-header surface

### Requirement: Mobile GUI keeps current-profile targeting separate from detail navigation

The system SHALL keep opening a saved profile for inspection or editing
separate from making that profile the current `Home` target.

#### Scenario: Opening a profile does not implicitly retarget Home

- **GIVEN** the mobile shell contains more than one saved profile
- **WHEN** the operator opens a profile from the `Profiles` list for detail or
  editing
- **THEN** the shell opens or focuses that profile detail surface
- **AND** the current profile used by `Home` remains unchanged until the
  operator explicitly chooses the make-current action

#### Scenario: Restored shell state keeps current profile separate from focused detail

- **GIVEN** the operator last used one profile as the current `Home` target and
  a different profile as the focused detail or editing context
- **WHEN** the mobile shell restores local shell state after restart
- **THEN** it restores those two contexts separately
- **AND** it does not silently collapse them back into one implicit selection

### Requirement: Mobile GUI exposes first-class root actions for providers and templates

The system SHALL expose managed-provider and user-template actions from the
primary `Providers` workflow surface instead of leaving those actions buried in
provider editors or create-only flows.

#### Scenario: Providers root exposes reusable-record actions

- **GIVEN** one or more saved managed providers exist in mobile shell state
- **WHEN** the operator opens the `Providers` workflow
- **THEN** the shell exposes `New provider` from the root command surface and a
  selection-aware root action row for `Copy`, `Use in profile`,
  `Save as template`, `Edit`, and `Delete`
- **AND** the operator does not need to open the provider editor just to
  discover those reusable-record actions

#### Scenario: Templates are first-class in the Providers workflow

- **GIVEN** the shell supports user templates and shipped presets
- **WHEN** the operator opens the `Providers` workflow
- **THEN** templates are reachable as a first-class `Providers` surface instead
  of only through the create-provider chooser
- **AND** user-template actions such as `Use`, `Copy`, `Edit`, and `Delete`
  are visible from that template surface
- **AND** those focused-template actions use the same selection-aware root-row
  pattern rather than a second detail-header cluster
- **AND** shipped presets remain part of the provider-create bootstrap flow
  rather than becoming a second editable template-management surface

### Requirement: Mobile GUI offers explicit duplicate semantics for reusable entities

The system SHALL let the operator duplicate saved profiles, managed providers,
and user templates without mutating the source record.

#### Scenario: Duplicating a profile creates a new draft

- **GIVEN** a saved profile exists in the mobile shell
- **WHEN** the operator chooses `Copy` for that profile
- **THEN** the shell creates a new unsaved profile draft seeded by snapshot
  copy from the source profile
- **AND** the later saved copy receives a fresh local id
- **AND** the copy action does not auto-connect, auto-resolve, or auto-start a
  session

#### Scenario: Duplicating a provider or template preserves the source

- **GIVEN** a saved managed provider or user template exists
- **WHEN** the operator chooses `Copy` for that reusable record
- **THEN** the shell seeds a new draft or template record by snapshot copy
- **AND** editing the copied draft does not mutate the source record in place

### Requirement: Mobile editors keep secondary entity actions off the commit footer

The system SHALL keep profile, provider, and template editor footers focused on
commit actions while secondary entity-management actions live on root or detail
command surfaces.

#### Scenario: Profile editor footer stays focused

- **GIVEN** the operator is editing a mobile profile
- **WHEN** the profile editor first appears
- **THEN** the visible commit footer prioritizes save plus start-or-resolve
  actions
- **AND** secondary actions such as import, export, copy, and delete do not
  compete for the same footer slot

#### Scenario: Provider and template editors stay focused

- **GIVEN** the operator is editing a saved provider or template
- **WHEN** that editor surface appears
- **THEN** the visible commit footer stays limited to save-oriented workflow
  actions
- **AND** record-management helpers such as copy or delete remain available
  from the surrounding `Providers` workflow instead of overloading the editor
  footer
