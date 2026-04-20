## ADDED Requirements
### Requirement: Mobile GUI exposes a development local-network routing profile separately from app scope

The system SHALL present development-oriented local-network preservation as a
separate routing-profile choice instead of collapsing it into app-selection
scope or a different Android runtime mode.

#### Scenario: Routing surface offers the development Wi-Fi profile

- **GIVEN** the connected Android host advertises support for the typed
  underlay-route policy `preserve_active_local_network`
- **WHEN** the operator opens the mobile routing surface
- **THEN** the UI presents a separate development-oriented routing profile such
  as `Development Wi-Fi`
- **AND** the profile is described as preserving the active local network while
  the Android system VPN remains active
- **AND** that choice stays separate from `all apps`, `included apps`, and
  `excluded apps` scope selection

#### Scenario: Unsupported host does not show a misleading development profile

- **GIVEN** the connected host does not advertise development local-network
  preservation for the current Android VPN mode
- **WHEN** the operator opens the routing surface
- **THEN** the mobile shell does not present `Development Wi-Fi` as if it were
  available
- **AND** it does not imply that ordinary app-routing scope already preserves
  the local debug path

#### Scenario: Operator changes the development local-network profile

- **GIVEN** the operator changes the underlay-route profile for the active
  Android VPN mode
- **WHEN** the shell applies that change
- **THEN** the shell treats it as a VPN startup preference that requires a
  restart to take effect
- **AND** it does not silently pretend that the active tunnel was mutated in
  place

#### Scenario: Operator updates visible app flags in bulk

- **GIVEN** the operator is using `included apps` or `excluded apps` scope on
  the mobile routing surface
- **AND** the app list is filtered by the current search query
- **WHEN** the operator applies a bulk select or bulk clear action
- **THEN** the shell updates the flags for the currently visible app set in one
  action
- **AND** it does not silently mutate apps that are outside the current
  filtered result set
