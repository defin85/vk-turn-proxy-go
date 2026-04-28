## ADDED Requirements

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
