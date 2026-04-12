## ADDED Requirements
### Requirement: Mobile GUI shell uses workflow-first navigation

The system SHALL present the mobile GUI shell through workflow-first navigation
or drill-down destinations instead of a single fixed-height stacked dashboard.

#### Scenario: Operator opens the mobile shell

- **GIVEN** the mobile GUI shell starts on a phone-sized layout
- **WHEN** the operator lands on the primary app surface
- **THEN** the first-class mobile view focuses on profile selection or editing
  plus resolve/start actions
- **AND** resolutions, sessions, and diagnostics are reached through secondary
  destinations or drill-down surfaces rather than occupying the same initial
  dashboard stack

#### Scenario: Operator inspects live activity

- **GIVEN** the mobile GUI shell has active or recent resolutions and sessions
- **WHEN** the operator navigates from the primary workflow into activity
- **THEN** the shell presents that activity in a dedicated mobile-sized surface
- **AND** returning to the primary workflow does not discard the selected draft
  or current operator context

### Requirement: Mobile GUI shell uses progressive disclosure for advanced and secondary actions

The system SHALL use progressive disclosure for advanced runtime controls,
diagnostics, and secondary resolution/session actions on mobile-sized screens.

#### Scenario: Profile contains advanced runtime overrides

- **GIVEN** the operator is editing a mobile profile that includes advanced
  runtime overrides or verbose provider guidance
- **WHEN** the profile editor first appears
- **THEN** the primary inputs and primary actions remain immediately visible
- **AND** advanced or support-oriented content stays behind explicit disclosure

#### Scenario: Resolution exposes multiple supported actions

- **GIVEN** a mobile resolution exposes multiple supported follow-up actions
- **WHEN** the operator views that resolution on a mobile-sized layout
- **THEN** the shell presents one clear primary action for the current context
- **AND** secondary actions are available through compact affordances rather
  than a full inline action matrix
