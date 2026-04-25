## ADDED Requirements

### Requirement: Windows desktop app routing requires process-to-flow classification

The system SHALL require a verified Windows process-to-flow classifier or
equivalent enforcement layer before advertising desktop app routing for
`windows_wintun`.

#### Scenario: Windows Wintun is ready without app classification

- **GIVEN** a Windows host can start `windows_wintun`
- **AND** the host lacks a verified process-to-flow classifier or equivalent
  enforcement layer
- **WHEN** the shell queries desktop app-routing support
- **THEN** the host reports app routing as unavailable for `windows_wintun`
- **AND** startup rejects desktop app-routing selectors for that mode

#### Scenario: Windows classifier validates selected app traffic

- **GIVEN** a Windows host advertises desktop app routing for `windows_wintun`
- **AND** the operator selects an enforceable Windows app identity
- **WHEN** startup validates the selected policy
- **THEN** the host verifies that outbound flows from that identity can be
  classified before readiness
- **AND** it applies the selected policy before the flow enters the tunnel path

### Requirement: Windows app inventory is host-owned and enforceability-aware

The system SHALL have the packaged Windows host enumerate and validate Windows
desktop application identities rather than asking the Flutter shell to infer
identity from local file paths.

#### Scenario: Windows host reports app inventory

- **GIVEN** a Windows desktop host supports app inventory
- **WHEN** the shell requests selectable desktop apps
- **THEN** the host returns display metadata and stable host-owned identity keys
  for apps it can resolve
- **AND** each app reports whether it is enforceable for the current classifier
  path
- **AND** the shell does not construct selector keys from path strings alone

#### Scenario: Selected Windows identity becomes stale

- **GIVEN** the shell submits a previously saved Windows app selector
- **AND** the host can no longer resolve or enforce that identity
- **WHEN** startup validation runs
- **THEN** startup fails with a typed app-routing prerequisite failure
- **AND** the host does not route all apps as a fallback

### Requirement: Windows app-routing evidence proves both inclusion and exclusion

The system SHALL require deterministic Windows evidence before claiming
app-routing support for a packaged host build.

#### Scenario: Selected app is routed and non-selected app is not widened

- **GIVEN** a Windows build claims app-routing support for `windows_wintun`
- **WHEN** the repo-owned verification smoke starts one selected app and one
  non-selected app under the same policy
- **THEN** evidence proves selected app traffic follows the requested tunnel
  path
- **AND** evidence proves the non-selected app is not silently captured by that
  policy
- **AND** the support claim is not accepted without both observations
