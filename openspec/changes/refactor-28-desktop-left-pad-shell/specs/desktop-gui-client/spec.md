## MODIFIED Requirements
### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a left-pad workspace where a
compact persistent navigation pad stays on the left and one main canvas owns
the active task surface.

#### Scenario: Shell opens into one active canvas route in routine ready state

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the shell shows a compact left pad plus one dominant main-canvas
  task route
- **AND** the shell does not stack multiple explanatory context cards beside
  the active editor
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant region

#### Scenario: Operator switches task entry from the left pad

- **GIVEN** the operator is inside the desktop shell
- **WHEN** the operator uses the left pad to switch workflows or open a task
  entry surface
- **THEN** the main canvas changes to the requested route
- **AND** the left pad remains a stable navigation surface instead of becoming
  a second detail pane

## ADDED Requirements
### Requirement: Desktop GUI shell uses canvas-routed secondary task surfaces

The system SHALL route saved-profile browsing, preset bootstrap,
managed-provider browsing, and provider-family selection through dedicated
main-canvas task surfaces instead of relying on modal-first overlays or
persistent companion cards.

#### Scenario: Operator opens a library or chooser from the active workflow

- **GIVEN** the operator is in an active desktop workflow
- **WHEN** the operator chooses saved profiles, presets, managed providers, or
  provider families
- **THEN** the shell opens that surface inside the main canvas as a dedicated
  route with an explicit back path
- **AND** the shell does not require a modal overlay as the primary interaction
  model for that flow

#### Scenario: Operator returns from a canvas-routed chooser without losing work

- **GIVEN** the operator has an in-progress draft or selected entity in the
  active desktop workflow
- **WHEN** the operator exits a canvas-routed chooser without applying a new
  selection
- **THEN** the shell returns to the prior editor route
- **AND** it preserves the draft and active selection state

### Requirement: Desktop GUI shell avoids duplicated task summaries beside the active canvas

The system SHALL avoid persistent summary cards or companion panes that restate
the same entity or task already open in the main canvas.

#### Scenario: Active profile editor is open

- **GIVEN** the profile editor route is active in the desktop shell
- **WHEN** the operator views the full shell layout
- **THEN** the shell does not render separate persistent summary cards for that
  same profile or draft beside the editor
- **AND** the left pad stays compact and command-oriented

#### Scenario: Active managed-provider editor is open

- **GIVEN** the managed-provider editor route is active in the desktop shell
- **WHEN** the operator views the full shell layout
- **THEN** the shell does not render a second persistent companion surface that
  repeats the same record context through stacked cards
- **AND** the main canvas remains the only substantive detail surface for that
  task
