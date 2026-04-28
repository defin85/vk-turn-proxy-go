## ADDED Requirements

### Requirement: Desktop GUI uses the shared structured VPN profile editor

The desktop GUI SHALL use the shared structured VPN transport profile editor
for profile-store-capable desktop hosts instead of requiring workstation-local
WireGuard files as the only configuration path.

#### Scenario: Desktop host advertises editable profile schema

- **GIVEN** a desktop host reports a profile-backed platform tunnel mode
- **AND** the host advertises structured editing for the required transport
  profile kind
- **WHEN** the operator opens the desktop Home or Routing setup surface
- **THEN** the GUI offers create, edit, replace, import, and forget actions for
  the VPN transport profile
- **AND** startup remains profile-reference based
- **AND** workstation-local environment/default WireGuard paths are not shown as
  product profile state

#### Scenario: Desktop host does not support structured editing

- **GIVEN** a desktop host advertises profile-store support but not structured
  editing for the required kind
- **WHEN** the operator opens the desktop setup surface
- **THEN** the GUI offers only the host-advertised actions such as import,
  replace, forget, or select-for-startup
- **AND** it does not render editable fields that the host has not advertised
