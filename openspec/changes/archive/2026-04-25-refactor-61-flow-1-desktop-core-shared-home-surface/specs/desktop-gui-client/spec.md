## MODIFIED Requirements

### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a stable VPN workbench with
one dominant task canvas, persistent left navigation on ordinary desktop
widths, and support-oriented live-work surfaces that do not compete equally
with the active route.

#### Scenario: Shell opens into one active desktop task route

- **GIVEN** the desktop GUI shell opens with no blocking host error
- **WHEN** the operator lands on the main screen
- **THEN** the shell shows a stable desktop navigation region plus one dominant
  task canvas
- **AND** the shell may embed a shared product workflow body inside the active
  route when that body is platform-neutral
- **AND** the shell does not treat multiple peer dashboard regions as equal
  primary work surfaces by default
- **AND** the shell does not stack route-restating action cards beside or above
  the active canvas route
- **AND** the shell does not present a second persistent peer region that
  competes with the active canvas route for substantive operator attention
- **AND** diagnostics and live-work surfaces stay secondary to the active route

#### Scenario: Narrow desktop widths preserve the same destination model

- **GIVEN** the desktop shell is running at a narrower desktop width
- **WHEN** the left navigation collapses into a compact surface
- **THEN** the shell preserves the same destination model and active route
- **AND** it does not fall back to a mobile-style stacked dashboard as the
  primary desktop pattern

### Requirement: Desktop home acts as an overview and command surface

The system SHALL keep desktop home concise and operational instead of using it
as the default location for all editing and support content, and SHALL render
platform-neutral shared Home workflow bodies without promoting duplicate
desktop-only chrome to a competing first read.

#### Scenario: Operator opens desktop home in routine ready state

- **GIVEN** the local host is ready and the desktop shell is in routine use
- **WHEN** the operator opens home
- **THEN** the shell shows compact overview information such as current mode,
  selected profile or active summary, and quick entry actions
- **AND** home does not expand into the full profile editor, routing editor,
  or raw diagnostics feed by default

#### Scenario: Home exposes support drill-down without becoming a diagnostics page

- **GIVEN** the shell has live sessions, recent resolutions, or typed host
  failures
- **WHEN** the operator views home
- **THEN** the shell exposes compact support entry points into activity or
  diagnostics
- **AND** the home route remains an overview rather than a full support work
  surface

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
