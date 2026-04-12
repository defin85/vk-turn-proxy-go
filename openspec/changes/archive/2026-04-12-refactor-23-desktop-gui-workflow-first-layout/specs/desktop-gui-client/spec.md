## ADDED Requirements
### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a workflow-first workspace
where saved-profile navigation is distinct from the active editor and live work
surface.

#### Scenario: Operator switches between saved profiles

- **GIVEN** the desktop GUI shell has multiple saved profiles
- **WHEN** the operator selects a profile from the saved-profile navigation
- **THEN** the active workspace updates to that profile's draft and actions
- **AND** saved-profile navigation remains available without mixing the full
  editor into the same navigation surface

#### Scenario: Shell opens with no active runtime work

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the primary visual focus is profile creation, selection, and
  resolve/start actions
- **AND** empty resolutions, sessions, and event diagnostics do not occupy the
  dominant workspace area

### Requirement: Desktop GUI shell consolidates operational state

The system SHALL present host readiness, compatibility, notices, and
platform-tunnel summary through one consolidated operational header with
progressive disclosure for secondary detail.

#### Scenario: Host is ready but platform tunnel support is unavailable

- **GIVEN** the desktop GUI shell is connected to a compatible host
- **AND** the packaged host reports no available platform-tunnel mode
- **WHEN** the operator views the main shell screen
- **THEN** the shell shows one consolidated operational summary instead of
  separate competing top-of-screen banners
- **AND** the operator can still inspect the platform-tunnel explanation

#### Scenario: Host is blocked or incompatible

- **GIVEN** the desktop GUI shell cannot manage runtime work because the host is
  blocked or incompatible
- **WHEN** the operator views the shell
- **THEN** the consolidated operational header explicitly reports the blocked
  state and required operator action
- **AND** the shell does not hide that failure behind secondary diagnostics
