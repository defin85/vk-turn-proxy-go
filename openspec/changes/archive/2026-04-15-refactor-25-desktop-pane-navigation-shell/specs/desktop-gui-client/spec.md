## MODIFIED Requirements
### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a workflow-first, pane-based
workspace where leading navigation, primary body panes, and secondary
inspection surfaces have distinct responsibilities.

#### Scenario: Operator switches desktop workflow sections

- **GIVEN** the desktop GUI shell is open on a large or extra-large desktop
  window
- **WHEN** the operator switches between primary desktop workflow sections from
  the desktop shell's leading navigation
- **THEN** the shell updates the primary body panes for that section
- **AND** it does not render those sections as one long competing library stack
- **AND** presets remain subordinate seed actions inside the managed-provider
  workflow instead of becoming a peer top-level taxonomy
- **AND** diagnostics and live-work surfaces remain secondary instead of
  becoming peer top-level navigation by default

#### Scenario: Desktop window shrinks below a multi-pane layout

- **GIVEN** the operator is working in a desktop shell section with an active
  draft, selection, or inspector context
- **WHEN** the desktop window is resized below the width where the current
  multi-pane arrangement fits
- **THEN** the shell collapses navigation or secondary panes into a compact
  desktop-appropriate presentation
- **AND** it preserves the operator's current draft, selection, and active
  context instead of resetting the workflow

#### Scenario: Shell opens with no active runtime work

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the primary visual focus is the active task pane or panes
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant peer column

### Requirement: Desktop GUI shell consolidates operational state

The system SHALL present host readiness, compatibility, notices, and
platform-tunnel summary through a compact shell bar with progressive disclosure
for secondary detail.

#### Scenario: Host is ready but platform tunnel support is unavailable

- **GIVEN** the desktop GUI shell is connected to a compatible host
- **AND** the packaged host reports no available platform-tunnel mode
- **WHEN** the operator views the main shell screen
- **THEN** the shell shows one compact operational summary instead of a
  hero-sized dashboard band
- **AND** the operator can still inspect the platform-tunnel explanation

#### Scenario: Host is blocked or incompatible

- **GIVEN** the desktop GUI shell cannot manage runtime work because the host is
  blocked or incompatible
- **WHEN** the operator views the shell
- **THEN** the compact shell bar or adjacent pinned explanation explicitly
  reports the blocked state and required operator action
- **AND** the shell does not hide that failure behind secondary diagnostics

## ADDED Requirements
### Requirement: Desktop GUI shell keeps diagnostics and live work in secondary inspectors

The system SHALL surface diagnostics, tunnel detail, event stream, and live
runtime work through contextual secondary inspector surfaces rather than a
permanently dominant dashboard column.

#### Scenario: Operator explicitly opens diagnostics from the primary workflow

- **GIVEN** the operator is working in the primary desktop task pane
- **AND** the host is ready
- **WHEN** the operator opens diagnostics, tunnel detail, or live work
- **THEN** the shell presents that content in a secondary inspector pane, side
  sheet, or context-appropriate secondary panel
- **AND** closing that inspector returns focus to the primary task pane without
  resetting the current draft or selection

#### Scenario: Inspector adapts to narrower desktop widths

- **GIVEN** the desktop shell uses an inspector-capable layout
- **AND** the operator has opened diagnostics or live work
- **WHEN** the desktop width no longer supports a coplanar side inspector
- **THEN** the shell can transition that inspector into a narrower
  desktop-appropriate presentation such as an end-drawer or equivalent overlay
- **AND** the transition preserves the currently selected task and inspector
  context

#### Scenario: Operator needs support detail for blocked or active runtime state

- **GIVEN** the host is blocked, incompatible, or the shell has active runtime
  work that exposes typed detail
- **WHEN** the operator reaches the main desktop shell
- **THEN** the shell keeps the relevant summary immediately visible from the
  primary surface
- **AND** the full support detail remains reachable through the secondary
  inspector model without navigating to a separate screen
