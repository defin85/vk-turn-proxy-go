## ADDED Requirements

### Requirement: Mobile GUI exposes explicit Android WireGuard profile configuration

The mobile GUI SHALL expose Android WireGuard profile configuration as an
operator-visible runtime setting for `android_vpn_service` strict
`turn_datagram + wireguard_native` startup. The GUI SHALL NOT depend on hidden
`phone1.conf` assets, workstation-local files, or build-time profile staging.

#### Scenario: Android VPN startup blocks on missing explicit profile

- **GIVEN** the selected mobile mode is `android_vpn_service`
- **AND** the selected execution plan is strict
  `turn_datagram + wireguard_native`
- **AND** no app-owned Android WireGuard profile is configured
- **WHEN** the operator views the mobile Home workflow
- **THEN** the primary action surfaces setup-needed state instead of starting
  VPN
- **AND** the setup action lets the operator import a WireGuard configuration in
  the app

#### Scenario: Operator imports or replaces Android WireGuard profile

- **GIVEN** the mobile shell is running on Android
- **WHEN** the operator imports or replaces a WireGuard configuration
- **THEN** the app stores an app-owned private copy
- **AND** the native bridge exposes that app-owned profile path to the embedded
  host materializer
- **AND** ordinary mobile shell state does not persist the raw private key

#### Scenario: Operator forgets Android WireGuard profile

- **GIVEN** an app-owned Android WireGuard profile is configured
- **WHEN** the operator chooses to forget it
- **THEN** the app deletes the app-owned copy
- **AND** subsequent strict Android WireGuard startup returns to setup-needed
  state until a profile is imported again
