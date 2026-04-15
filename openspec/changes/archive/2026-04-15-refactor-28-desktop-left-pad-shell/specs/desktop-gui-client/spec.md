## MODIFIED Requirements
### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a left-pad workspace where
large desktop widths keep a compact persistent navigation pad on the left,
narrower desktop widths expose the same workflow and task-entry commands
through a compact drawer or equivalent trigger, and one main canvas owns the
active task surface.

#### Scenario: Shell opens into one active canvas route in routine ready state

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the shell shows a compact left pad plus one dominant main-canvas
  task route
- **AND** the shell does not stack multiple explanatory context cards or
  route-restating action cards beside or above the active canvas route
- **AND** the shell does not present a second persistent peer region that
  competes with the active canvas route for substantive operator attention
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant region

#### Scenario: Operator switches task entry from the left pad

- **GIVEN** the operator is inside the desktop shell
- **WHEN** the operator uses the left pad to switch workflows or open a task
  entry surface
- **THEN** the main canvas changes to the requested route
- **AND** the left pad remains a stable navigation surface instead of becoming
  a second detail pane
- **AND** routine task-entry commands do not require a separate persistent
  explanatory card above the active route

#### Scenario: Narrow desktop widths collapse the left pad without changing the active task

- **GIVEN** the desktop GUI shell is running in a narrower desktop-width window
- **WHEN** the operator opens workflow navigation or task-entry commands
- **THEN** the shell exposes the same workflow and task-entry actions through a
  compact drawer or equivalent trigger
- **AND** opening or closing that compact navigation surface does not discard
  the active canvas route, draft state, or active selection
- **AND** the shell does not restore a separate persistent summary pane beside
  the active canvas as a fallback for the collapsed left pad

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

#### Scenario: Canvas-routed chooser exposes an explicit in-canvas return path

- **GIVEN** a saved-profile, preset, managed-provider, or provider-family
  chooser is active in the main canvas
- **WHEN** the operator views that chooser route
- **THEN** the route exposes its own title and explicit back affordance inside
  the main canvas
- **AND** using that back affordance returns to the prior workflow route
  without relying on modal dismissal as the primary interaction model

### Requirement: Desktop GUI shell avoids duplicated task summaries around the active canvas

The system SHALL avoid persistent summary cards or companion panes that restate
the same entity or task already open in the main canvas.

#### Scenario: Active profile editor is open

- **GIVEN** the profile editor route is active in the desktop shell
- **WHEN** the operator views the full shell layout
- **THEN** the shell does not render separate persistent summary cards or
  route-restating action cards for that same profile or draft beside or above
  the editor
- **AND** the left pad stays compact and command-oriented

#### Scenario: Active managed-provider editor is open

- **GIVEN** the managed-provider editor route is active in the desktop shell
- **WHEN** the operator views the full shell layout
- **THEN** the shell does not render a second persistent companion surface or
  route-restating action card that repeats the same record context through
  stacked cards beside or above the editor
- **AND** the main canvas remains the only substantive detail surface for that
  task

#### Scenario: Routine ready shell avoids multi-region card dashboards

- **GIVEN** the desktop GUI shell is in a routine ready state on a desktop-width
  window
- **WHEN** the operator views the first screen without opening diagnostics or
  live work
- **THEN** the screen reads as `left pad + one dominant canvas + optional
  inspector`
- **AND** the default ready layout does not read as multiple equal-weight card
  regions competing for the operator's first attention
