## ADDED Requirements

### Requirement: Android WireGuard materializer uses explicit app-owned profile state

The Android embedded host SHALL materialize strict
`turn_datagram + wireguard_native` leases only from an app-owned WireGuard
profile path explicitly configured by the mobile app at runtime. It SHALL NOT
read workstation-local WireGuard profile environment variables, packaged
`assets/wireguard/phone1.conf`, or other hidden seed assets.

#### Scenario: Missing explicit Android profile fails closed

- **GIVEN** the packaged Android host supports `android_vpn_service`
- **AND** no app-owned WireGuard profile has been configured through the mobile
  runtime surface
- **WHEN** the host materializes a strict
  `turn_datagram + wireguard_native` runtime lease
- **THEN** materialization fails closed before VPN readiness is reported
- **AND** the diagnostic names the missing explicit Android WireGuard profile

#### Scenario: Imported profile path is the only Android materializer input

- **GIVEN** the operator imports a WireGuard profile through the mobile app
- **WHEN** the Android embedded host is started or restarted
- **THEN** the native bridge passes the app-private profile path to the host
  materializer
- **AND** the host uses that app-owned path instead of any packaged asset or
  workstation-local default

#### Scenario: Android package inspection rejects legacy packaged profile seed

- **GIVEN** an Android debug or release package is built
- **WHEN** package contents are inspected
- **THEN** `assets/wireguard/phone1.conf` and equivalent packaged WireGuard seed
  assets are absent
