## ADDED Requirements

### Requirement: Windows app-routing prerequisites are distinct from Wintun readiness

The system SHALL report Windows app-routing classifier and enforcement
prerequisites separately from `windows_wintun` adapter, route, and runtime
attach readiness.

#### Scenario: Wintun startup succeeds but app routing is unavailable

- **GIVEN** a Windows host satisfies the documented `windows_wintun` startup
  prerequisites
- **AND** it lacks the app classifier or enforcement prerequisites
- **WHEN** the host reports platform tunnel capability and startup state
- **THEN** `windows_wintun` readiness remains governed by the existing platform
  tunnel contract
- **AND** desktop app routing remains explicitly unavailable for that mode
- **AND** the host does not collapse classifier absence into a generic Wintun
  failure

#### Scenario: App-routed Windows startup fails after partial classifier setup

- **GIVEN** a Windows host starts `windows_wintun` with desktop app-routing
  selectors
- **AND** classifier or enforcement setup partially succeeds before a later
  prerequisite fails
- **WHEN** startup returns failure
- **THEN** the host tears down partial app-routing resources before returning
  the failure
- **AND** the failure identifies the app-routing prerequisite or stage instead
  of reporting only adapter readiness
