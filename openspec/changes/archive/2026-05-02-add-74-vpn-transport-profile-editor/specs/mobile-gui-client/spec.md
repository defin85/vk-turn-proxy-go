## ADDED Requirements

### Requirement: Mobile GUI provides a structured VPN profile editor

The mobile GUI SHALL let operators create and edit required VPN transport
profiles through a structured product UI when the embedded host advertises an
editable profile schema.

#### Scenario: Missing profile offers create/edit path

- **GIVEN** the active mobile VPN execution plan requires
  `wireguard_native_v1`
- **AND** no compatible profile is configured
- **AND** the host advertises structured editing for that kind
- **WHEN** the operator inspects the Home or Routing setup surface
- **THEN** the primary setup path opens a VPN transport profile editor
- **AND** WireGuard `.conf` import remains available as an alternate path
- **AND** VPN startup stays disabled until a valid compatible profile is saved

#### Scenario: Operator saves structured WireGuard profile

- **GIVEN** the operator is editing a WireGuard transport profile
- **WHEN** they provide valid required fields or request host-side key
  generation and save
- **THEN** the UI calls the structured profile-store operation
- **AND** it returns to configured status with replace, edit, forget, and start
  actions
- **AND** it does not persist raw private-key material in shell state

### Requirement: Mobile GUI handles profile editor errors inline

The mobile GUI SHALL show structured profile validation errors near the fields
that caused them and keep the previous profile state intact.

#### Scenario: Invalid edit is rejected

- **GIVEN** a compatible transport profile is already configured
- **WHEN** the operator submits an invalid edit
- **THEN** the UI shows field-level errors and a setup notice
- **AND** the previous configured profile remains selected for startup
- **AND** secret fields are cleared or redacted after the failed submit
