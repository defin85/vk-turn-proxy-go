## ADDED Requirements

### Requirement: Desktop GUI uses the shared VPN transport profile workflow

The desktop GUI SHALL use the shared VPN transport profile workflow for
profile-backed desktop platform tunnel modes instead of exposing
workstation-local WireGuard paths as the product configuration model.

#### Scenario: Desktop WireGuard setup is profile-store driven

- **GIVEN** a desktop host reports `windows_wintun` startup that requires a
  `wireguard_native_v1` transport profile
- **WHEN** the operator inspects the desktop VPN setup surface
- **THEN** the GUI presents VPN transport profile setup, status, replace, and
  forget actions
- **AND** WireGuard `.conf` appears only as an import adapter for the
  `wireguard_native_v1` profile kind

#### Scenario: Desktop host lacks profile-store support

- **GIVEN** a desktop host still relies on development env/default WireGuard
  paths and does not advertise profile-store capability
- **WHEN** the operator inspects product VPN setup
- **THEN** the GUI does not present that path as configured product transport
  profile state
- **AND** startup remains unavailable or setup-needed until a profile-store
  capable host reports compatible profile status
