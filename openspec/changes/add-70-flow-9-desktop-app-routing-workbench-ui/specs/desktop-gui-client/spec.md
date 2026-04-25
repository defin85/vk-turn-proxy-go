## ADDED Requirements

### Requirement: Desktop GUI presents app routing as a separate Routing workbench section

The system SHALL present desktop application routing as an explicit Routing
workbench section that is separate from IP address, underlay-route, and
advanced runtime fields.

#### Scenario: Desktop host does not support app routing

- **GIVEN** the desktop shell is connected to a host that does not advertise
  desktop app-routing support
- **WHEN** the operator opens the Routing workbench
- **THEN** the shell shows app routing as unavailable or prerequisite-blocked
  for the current host
- **AND** it does not present app checkboxes that would imply enforceable
  routing
- **AND** existing IP routing and platform-tunnel status remain usable

#### Scenario: Desktop host provides app inventory

- **GIVEN** the desktop shell is connected to a host that advertises desktop
  app-routing support
- **AND** the host provides app inventory and supported policy kinds
- **WHEN** the operator opens the app-routing section
- **THEN** the shell renders selectable host-provided applications with their
  display names and identity detail
- **AND** it disables or explains identities that the host reports as
  unenforceable
- **AND** it does not build selector identity from shell-local path parsing

#### Scenario: Operator changes desktop app-routing selection

- **GIVEN** a desktop profile has app-routing selector intent
- **WHEN** the operator changes the selected apps or policy
- **THEN** the shell saves the new profile intent
- **AND** if a tunnel is already ready, the shell communicates that the change
  requires reconnect or a new startup attempt before it affects runtime scope

### Requirement: Desktop GUI keeps app-routing controls honest across host versions

The system SHALL keep app-routing controls fail-closed when the connected host
is older, incompatible, or missing desktop app-routing metadata.

#### Scenario: Older host lacks desktop app-routing metadata

- **GIVEN** the desktop shell supports the app-routing UI
- **AND** the connected host predates the desktop app-routing capability
- **WHEN** capability negotiation completes
- **THEN** the shell treats desktop app routing as unsupported
- **AND** it does not infer support from `windows_wintun` or platform tunnel
  availability

#### Scenario: Saved app selector cannot be validated

- **GIVEN** a desktop profile contains saved app-routing selector intent
- **AND** the connected host reports that one selector is stale or
  unenforceable
- **WHEN** the operator attempts startup from that profile
- **THEN** the shell surfaces the host validation failure
- **AND** it does not silently replace the profile intent with all-app routing
