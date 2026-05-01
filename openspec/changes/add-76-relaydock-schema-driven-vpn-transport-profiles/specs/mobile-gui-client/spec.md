## ADDED Requirements

### Requirement: Mobile GUI renders VPN profile editors from host schemas

The mobile GUI SHALL render VPN transport profile create and edit flows from
host-advertised structured schemas instead of using a WireGuard-only form.

#### Scenario: Mobile shell renders non-WireGuard profile setup

- **GIVEN** the embedded host advertises an editable VPN transport profile kind
  with a structured schema
- **WHEN** the operator opens the RelayDock profile setup flow from Home or
  Routing
- **THEN** the mobile shell renders supported fields from the advertised schema
- **AND** it labels the concrete profile kind from host or shell metadata
- **AND** it does not show WireGuard-only controls such as `.conf` import,
  private-key generation, peer public key, or allowed IPs unless the schema or
  adapter metadata advertises those controls for the required kind

#### Scenario: Mobile shell keeps startup disabled for editable-only kinds

- **GIVEN** the mobile shell can render a profile editor for a future profile
  kind
- **AND** the host does not advertise a supported runtime execution plan for
  that kind
- **WHEN** the operator saves or views that profile
- **THEN** the shell shows the profile as configured or unsupported according
  to host status
- **AND** the primary VPN connect action on Home remains unavailable with an
  explicit support or prerequisite reason

#### Scenario: Mobile shell rejects unsupported schema fields

- **GIVEN** the embedded host advertises a VPN transport profile schema with a
  field or value kind unsupported by the mobile shell
- **WHEN** the operator opens the profile setup flow
- **THEN** the mobile shell reports structured editing as unsupported for that
  kind or field
- **AND** it does not render a guessed WireGuard control or submit partial
  profile material
- **AND** it may offer only host-advertised fallback actions that the mobile
  shell can execute

### Requirement: Mobile GUI keeps VPN start ownership on Home

The mobile GUI SHALL keep VPN connect and disconnect ownership on the Home
primary action while non-Home surfaces provide status and setup only.

#### Scenario: Routing links to setup without starting VPN

- **GIVEN** a VPN transport profile kind requires setup or edit
- **WHEN** the operator opens Routing
- **THEN** Routing may show profile status and setup/edit/import/forget links
- **AND** Routing does not duplicate Home's primary VPN connect or disconnect
  action for WireGuard or any future profile kind

### Requirement: Mobile GUI exposes a VPN transport profile manager

The mobile GUI SHALL provide a native RelayDock manager for multiple VPN
transport profiles when the host reports more than one configured or
configurable profile.

#### Scenario: Home opens transport profile manager from setup-needed state

- **GIVEN** Home cannot start VPN because the selected execution plan needs a
  VPN transport profile
- **WHEN** the operator opens the setup action
- **THEN** the mobile shell opens a VPN transport profile manager filtered to
  the required kind and execution plan
- **AND** the manager lists configured profiles with redacted status and
  compatibility
- **AND** it offers only host-advertised create, import, edit, forget,
  validate, and select actions

#### Scenario: Routing opens manager without owning startup

- **GIVEN** multiple VPN transport profiles are configured or configurable
- **WHEN** the operator opens Routing profile setup or status
- **THEN** Routing may open the same transport profile manager filtered to the
  active platform tunnel context
- **AND** choosing or editing a profile updates setup/default selection state
- **AND** VPN connect and disconnect remain Home primary actions

#### Scenario: Provider profiles stay separate

- **GIVEN** the operator is viewing product/provider Profiles
- **WHEN** a selected product profile requires native VPN transport material
- **THEN** Profiles may link to the VPN transport profile manager
- **AND** Profiles does not store raw transport secrets, choose implicit
  startup defaults, or become the primary transport-profile library
