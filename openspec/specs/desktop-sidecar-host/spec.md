# desktop-sidecar-host Specification

## Purpose
Define the packaged desktop host responsibilities for repo-owned desktop
platform-tunnel startup, including native adapter coordination, fail-closed
target support, and typed startup results.
## Requirements
### Requirement: Packaged desktop hosts own supported desktop ready paths

The system SHALL let the packaged desktop host own every supported desktop platform tunnel lifecycle so production desktop installs can start the documented system tunnel mode without an external VPN companion app or operator-managed route commands.

#### Scenario: Unsupported desktop target stays fail-closed

- **GIVEN** a production desktop package whose bundled host does not yet implement a documented ready path for the current desktop target
- **WHEN** the operator requests desktop system tunnel startup
- **THEN** the packaged host reports the typed failing stage and missing prerequisite explicitly
- **AND** the desktop app fails closed for that target instead of redirecting the operator to an undefined external host workflow

#### Scenario: Packaged Windows host starts the documented first desktop tunnel path

- **GIVEN** a production Windows desktop package with the documented bundled host and `windows_wintun` implementation
- **WHEN** the operator starts the packaged desktop system tunnel workflow
- **THEN** the packaged host owns driver preparation, route preparation, packet capture, and runtime attach for that mode
- **AND** the operator does not need an external `WireGuard for Windows` client or manual `route add` commands to reach the typed startup result

### Requirement: Packaged desktop host coordinates native tunnel startup behind one host boundary

The system SHALL let the packaged desktop host coordinate documented
system-tunnel startup through its native adapter boundary instead of routing
privileged tunnel work through the Flutter shell.

#### Scenario: Packaged desktop host starts one desktop mode through its native adapter

- **GIVEN** a production desktop package with the documented bundled host and
  one supported native desktop adapter
- **WHEN** the operator starts the packaged desktop system-tunnel workflow
- **THEN** the packaged desktop host reaches that native adapter through the
  documented host boundary
- **AND** the app does not require shell-local orchestration or an undefined
  second helper API to reach the typed startup result

### Requirement: Desktop hosts consume VPN transport profiles for product platform tunnels

Desktop packaged hosts SHALL consume local VPN transport material through the
VPN transport profile store before claiming product support for profile-backed
platform tunnel startup.

#### Scenario: Windows product startup uses profile reference

- **GIVEN** a packaged Windows host advertises `windows_wintun` with a
  profile-backed `wireguard_native` execution plan
- **WHEN** the shell starts that platform tunnel
- **THEN** startup uses a selected or scoped-default `wireguard_native_v1`
  transport profile reference
- **AND** the host does not require the operator to set an environment variable
  or place a WireGuard file at a workstation-local default path

#### Scenario: Desktop development path does not imply profile-store support

- **GIVEN** a desktop development build can still load WireGuard material from
  an explicit environment variable or lab default path
- **WHEN** the host reports product capabilities
- **THEN** that development input does not satisfy the VPN transport profile
  store capability by itself
- **AND** profile-store support is reported only after the host implements the
  typed profile lifecycle, redaction, and startup reference contract

### Requirement: Desktop hosts gate structured VPN profile editing on real host support

Desktop packaged hosts SHALL advertise structured VPN transport profile editing
only after the desktop host owns the schema, validation, persistence,
redaction, and startup materialization path for the advertised profile kind.

#### Scenario: Packaged desktop host advertises structured WireGuard editing

- **GIVEN** a packaged desktop host advertises structured editing for
  `wireguard_native_v1`
- **WHEN** a shell creates or updates a profile through the structured editor
- **THEN** the host persists the result in the host-owned transport-profile
  store
- **AND** ordinary status, diagnostics, and startup responses remain redacted
- **AND** `windows_wintun` startup materializes the WireGuard execution lease
  from the stored profile id rather than from workstation-local environment or
  default WireGuard paths

#### Scenario: Desktop host lacks structured edit materialization

- **GIVEN** a desktop host can import WireGuard `.conf` files but cannot yet
  validate and materialize structured fields for `windows_wintun`
- **WHEN** it reports transport-profile-store capability metadata
- **THEN** it advertises only import, replace, forget, validate, and
  select-for-startup lifecycle actions
- **AND** it does not advertise structured create/update schemas for that kind
