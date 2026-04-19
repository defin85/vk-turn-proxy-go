## ADDED Requirements
### Requirement: Mobile GUI shell uses task-aligned interaction surfaces

The system SHALL choose mobile interaction surfaces by task weight and content
depth instead of mixing centered dialogs, bottom sheets, and follow-on routes
for equivalent jobs.

#### Scenario: Operator changes a local routing parameter

- **GIVEN** the operator is already on a mobile workflow screen such as
  `Routing`
- **WHEN** they choose a local reversible parameter such as `Routing profile`
  or `App scope`
- **THEN** the shell presents that choice in a bottom sheet anchored to the
  current workflow
- **AND** dismissing the picker returns the operator to the same screen without
  entering a separate library-style flow

#### Scenario: Operator starts a catalog-style provider creation flow

- **GIVEN** the operator starts a mobile provider creation flow that includes
  provider families, templates, search, or multiple actions
- **WHEN** the shell opens that chooser
- **THEN** it presents the chooser as a dedicated follow-on mobile surface
  instead of a centered dialog
- **AND** that surface uses ordinary mobile back navigation
- **AND** it can scale to long lists or search without crowding the root
  workflow surface

#### Scenario: Operator opens a compact preview, confirmation, or status summary

- **GIVEN** the shell needs to show a compact preview, confirmation, or short
  contextual status summary
- **WHEN** that content does not require library-style browsing or multi-step
  navigation
- **THEN** the shell may present it as a dialog-sized overlay
- **AND** that overlay does not become the primary container for search-heavy,
  tabbed, or catalog-style flows
