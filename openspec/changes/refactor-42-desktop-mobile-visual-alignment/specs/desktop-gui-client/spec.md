## ADDED Requirements

### Requirement: Desktop GUI shell uses the mobile shell as its visual reference

The system SHALL render the desktop shell in the same product visual family as
the approved mobile shell while preserving desktop-first structure and
interaction.

#### Scenario: Routine desktop ready state matches the product visual family

- **GIVEN** the mobile shell is the approved visual reference for the current
  product direction
- **WHEN** the desktop shell renders its primary workbench surfaces
- **THEN** it uses the same product color semantics, surface hierarchy, and
  action-emphasis grammar
- **AND** it does not regress to a separate generic desktop-only brand
- **AND** it keeps desktop-sized density and navigation instead of imitating a
  phone layout

### Requirement: Desktop status and support surfaces stay visually recognizable across shells

The system SHALL keep blocked, ready, active-runtime, and support-oriented
desktop treatments visually consistent with the mobile shell's semantic state
language.

#### Scenario: Desktop surfaces a blocked or attention state

- **GIVEN** the desktop shell needs to show blocked host state, runtime
  attention, or support context
- **WHEN** it renders that state
- **THEN** the state uses the same semantic tone and status-treatment family as
  the mobile shell
- **AND** the treatment remains explicit without turning the desktop workbench
  into a stretched mobile screen
