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
- **AND** the shell may embed a shared product workflow body inside that
  canvas when the body itself is platform-neutral
- **AND** the shell does not stack multiple explanatory context cards or
  route-restating action cards beside or above the active canvas route
- **AND** the shell does not present a second persistent peer region that
  competes with the active canvas route for substantive operator attention
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant region

### Requirement: Desktop GUI shell keeps support and task-entry chrome secondary to the active Home body

The system SHALL keep routine desktop `Home` quick actions, support affordances,
and shell summaries secondary to the dominant `Home` workflow body.

#### Scenario: Desktop Home uses the shared product workflow body

- **GIVEN** the desktop shell renders the routine `Home` canvas in a ready
  state
- **WHEN** the product-facing `Home` body is available as a platform-neutral
  shared surface
- **THEN** the desktop canvas reuses that shared body instead of maintaining a
  separate desktop-only overview composition
- **AND** desktop task-entry or support affordances remain available through
  the left pad, drawer, or inspector model
- **AND** desktop-local `Home` chrome does not restate those same actions as a
  competing parallel first read
