## ADDED Requirements

### Requirement: Desktop GUI renders VPN profile editors from host schemas

The desktop GUI SHALL render VPN transport profile create and edit flows from
host-advertised structured schemas instead of assuming every profile is a
WireGuard profile.

#### Scenario: Desktop shell renders host-advertised profile fields

- **GIVEN** a desktop host advertises an editable VPN transport profile kind
  with a structured schema
- **WHEN** the operator opens the profile setup flow from Home or Routing
- **THEN** the desktop shell renders fields, secret actions, validation errors,
  and lifecycle actions from that schema
- **AND** the shell does not expose workstation-local WireGuard paths,
  WireGuard import, or WireGuard-only field labels unless those are advertised
  for the required kind

#### Scenario: Desktop shell fails closed on unsupported schema

- **GIVEN** a desktop host reports a profile kind whose schema contains fields
  or value kinds unsupported by the current shell
- **WHEN** the operator opens the setup surface
- **THEN** the shell reports structured editing as unsupported for that kind
- **AND** it offers only host-advertised fallback lifecycle actions such as
  import, replace, forget, or select-for-startup
- **AND** it does not submit partial or guessed profile material

### Requirement: Desktop GUI exposes a VPN transport profile manager

The desktop GUI SHALL provide a workbench-native manager for multiple VPN
transport profiles instead of assuming one implicit current transport profile.

#### Scenario: Desktop manager lists and selects compatible profiles

- **GIVEN** a desktop host reports multiple VPN transport profiles
- **WHEN** the operator opens VPN transport setup from Home or Routing
- **THEN** the desktop GUI lists profiles with redacted status, kind,
  compatibility, and default/selected state
- **AND** it filters or groups profiles by the active execution plan and
  required kind
- **AND** selecting a profile uses the host-advertised select-for-startup or
  scoped-default action rather than mutating provider profile state

#### Scenario: Desktop Profiles route links but does not own transport state

- **GIVEN** a desktop product profile depends on native VPN transport material
- **WHEN** the operator inspects that profile
- **THEN** the profile view may link to the VPN transport profile manager
- **AND** it does not expose raw transport material or become the primary
  transport-profile library
