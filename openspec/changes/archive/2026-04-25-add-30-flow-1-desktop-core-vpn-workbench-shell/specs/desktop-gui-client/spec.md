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
- **AND** the shell does not treat multiple peer dashboard regions as equal
  primary work surfaces by default
- **AND** diagnostics and live-work surfaces stay secondary to the active route

#### Scenario: Narrow desktop widths preserve the same destination model

- **GIVEN** the desktop shell is running at a narrower desktop width
- **WHEN** the left navigation collapses into a compact surface
- **THEN** the shell preserves the same destination model and active route
- **AND** it does not fall back to a mobile-style stacked dashboard as the
  primary desktop pattern

## ADDED Requirements
### Requirement: Desktop GUI shell uses explicit workbench destinations

The system SHALL organize the desktop VPN shell around explicit workbench
destinations rather than one large mixed dashboard.

#### Scenario: Operator navigates across the desktop shell

- **GIVEN** the operator is using the desktop shell on a routine workflow
- **WHEN** they move between the primary destinations
- **THEN** the shell offers explicit workbench routes such as home, profiles,
  routing, support-oriented activity or diagnostics, and settings
- **AND** each route owns the main task canvas when selected

#### Scenario: Operator switches routes without losing current context

- **GIVEN** the operator has a current selection, draft, or active session
  context
- **WHEN** they switch between desktop workbench destinations
- **THEN** the shell preserves that relevant context when appropriate
- **AND** returning to the previous route does not require rebuilding the
  workflow from scratch

### Requirement: Desktop home acts as an overview and command surface

The system SHALL keep desktop home concise and operational instead of using it
as the default location for all editing and support content.

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

### Requirement: Desktop GUI shell provides dense profile and routing surfaces

The system SHALL provide dedicated desktop-first work surfaces for profile and
routing management rather than relying on stretched phone-oriented layouts.

#### Scenario: Operator manages profiles on desktop

- **GIVEN** the operator needs to browse, select, edit, or create profiles on
  desktop
- **WHEN** they open the profile work surface
- **THEN** the shell presents a dense desktop workflow such as list-detail,
  table-detail, or an equivalent workbench composition
- **AND** profile management does not depend on scrolling through a home
  overview route

#### Scenario: Operator manages routing on desktop

- **GIVEN** the operator needs to inspect or edit routing behavior on desktop
- **WHEN** they open the routing work surface
- **THEN** the shell presents routing through a dedicated desktop page or
  workbench region
- **AND** routing does not remain hidden behind incidental support controls or
  a stretched mobile-derived editor

### Requirement: Desktop GUI shell keeps live runtime detail in a secondary live-work surface

The system SHALL keep logs, live connections, and similar runtime detail in a
secondary live-work surface such as a bottom ribbon or clearly subordinate
support pane.

#### Scenario: Operator inspects live runtime detail

- **GIVEN** the desktop shell exposes logs, live connections, or traffic
  detail
- **WHEN** the operator opens that live-work surface
- **THEN** the shell presents it in a lower ribbon, expandable lower panel, or
  explicitly secondary pane
- **AND** that live-work surface does not replace the main task canvas by
  default

#### Scenario: Live runtime detail remains quickly reachable

- **GIVEN** the operator is working on profiles, routing, or another desktop
  route
- **WHEN** they need logs or live connections
- **THEN** the shell can open that live-work surface without discarding the
  active route
- **AND** closing or collapsing that live-work surface restores focus to the
  active route
