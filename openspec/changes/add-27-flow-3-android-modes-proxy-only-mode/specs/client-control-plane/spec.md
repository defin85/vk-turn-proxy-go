## ADDED Requirements
### Requirement: Client control plane reports typed Android proxy-only mode state

The system SHALL expose the first Android proxy-only mode through typed
client-control-plane state instead of shell-local heuristics.

#### Scenario: Shell inspects or starts proxy-only mode

- **GIVEN** a packaged Android host that supports the documented proxy-only
  mode
- **WHEN** the mobile shell queries or starts that mode through the local
  control plane
- **THEN** the host reports typed availability plus ready/failure state for the
  proxy-only workflow
- **AND** any local proxy endpoint metadata needed by the shell is surfaced
  through the documented control-plane contract instead of logs or native-only
  side channels
