## MODIFIED Requirements
### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a focused workflow workspace
where one current operator task owns a dominant editor and adjacent workflows
remain in a quieter context lane.

#### Scenario: Shell opens into one dominant workflow with no active runtime work

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the shell presents one dominant workflow editor for the current
  profile or provider task
- **AND** adjacent workflows, recent records, and seed actions remain visible
  as secondary context instead of competing peer panes
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant region

#### Scenario: Operator switches workflow context without losing the current shell model

- **GIVEN** the desktop GUI shell exposes both `profileWorkflow` and
  `providerWorkflow`
- **WHEN** the operator switches workflow context from the shell's secondary
  context lane
- **THEN** the shell updates the dominant editor to that workflow
- **AND** it keeps workflow switching visually subordinate to the active editor
- **AND** presets remain seed actions inside the workflow model instead of a
  peer navigation taxonomy

#### Scenario: Desktop layout adapts without discarding focused workflow state

- **GIVEN** the operator is working in the focused desktop workflow with a
  current draft, selection, or open support context
- **WHEN** the desktop window crosses a layout threshold that changes how the
  context lane or support surface is presented
- **THEN** the shell adapts the layout for the available width
- **AND** it preserves the current draft, selection, and active support context
  instead of resetting the workflow

### Requirement: Desktop GUI shell consolidates operational state

The system SHALL present routine desktop host readiness as a compact assurance
surface while preserving explicit pinned guidance for blocked or incompatible
states.

#### Scenario: Host is ready in the normal desktop path

- **GIVEN** the desktop GUI shell is connected to a compatible host
- **AND** there is no blocked host condition that requires immediate operator
  intervention
- **WHEN** the operator views the main shell screen
- **THEN** the shell shows a compact readiness and capability summary adjacent
  to the active workflow
- **AND** that routine assurance does not visually outrank the dominant editor

#### Scenario: Host is blocked or incompatible

- **GIVEN** the desktop GUI shell cannot manage runtime work because the host is
  blocked or incompatible
- **WHEN** the operator views the shell
- **THEN** the shell pins explicit guidance and required operator action from
  the primary shell surface
- **AND** it does not hide that failure behind secondary support affordances

### Requirement: Desktop GUI shell keeps diagnostics and live work in secondary inspectors

The system SHALL keep diagnostics, tunnel detail, event stream, and live
runtime support surfaces secondary by default while making them explicitly
reachable and escalating them when state demands it.

#### Scenario: Routine ready state keeps support on demand

- **GIVEN** the desktop GUI shell is in a routine ready state
- **WHEN** the operator is working in the dominant workflow editor
- **THEN** diagnostics and live runtime support stay collapsed or secondary by
  default
- **AND** the operator can open them through explicit support affordances
- **AND** closing support returns focus to the current workflow without losing
  the current draft or selection

#### Scenario: Blocked or active runtime state escalates support visibility

- **GIVEN** the host is blocked or incompatible, or the shell has active
  runtime work that exposes typed support detail
- **WHEN** the operator reaches the main desktop shell
- **THEN** the shell keeps the relevant support summary immediately visible
  from the primary surface
- **AND** the full support detail remains reachable through the inspector model
  without turning routine ready-state into a permanent support dashboard

#### Scenario: Support inspector adapts across desktop widths

- **GIVEN** the operator has opened diagnostics or live runtime support from
  the focused workflow shell
- **WHEN** the desktop width no longer supports the current coplanar support
  presentation
- **THEN** the shell transitions support into a narrower desktop-appropriate
  presentation such as an end drawer or equivalent overlay
- **AND** it preserves the current workflow and support context during that
  transition

## ADDED Requirements
### Requirement: Desktop GUI shell gives the active workflow a step-aware action hierarchy

The system SHALL structure the active desktop workflow around the next
meaningful operator decisions instead of front-loading every advanced or
support-oriented control at once.

#### Scenario: Primary editor emphasizes the next meaningful actions

- **GIVEN** the operator opens the active desktop workflow editor
- **WHEN** the shell renders the current workflow
- **THEN** the primary editor shows the current task title, concise guidance,
  and a clear action hierarchy for the next meaningful operator step
- **AND** the shell keeps one primary action visually dominant over secondary
  actions

#### Scenario: Advanced detail uses progressive disclosure

- **GIVEN** the active desktop workflow contains advanced runtime defaults,
  support notes, or secondary explanation
- **WHEN** the operator first opens that workflow
- **THEN** the shell keeps core inputs and primary actions above the fold
- **AND** advanced or support-only detail uses progressive disclosure instead of
  competing with the first read of the workflow
