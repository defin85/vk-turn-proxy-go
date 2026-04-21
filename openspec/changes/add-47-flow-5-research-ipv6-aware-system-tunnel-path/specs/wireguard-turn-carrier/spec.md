## ADDED Requirements
### Requirement: Strict WireGuard execution leases keep address-family coverage explicit

The system SHALL keep the address-family coverage of a strict
`turn_datagram + wireguard_native` execution lease explicit and host-owned.

#### Scenario: Host materializes a family-complete dual-stack execution lease

- **GIVEN** a packaged host that claims one strict `turn_datagram`
  `wireguard_native` path can cover both IPv4 and IPv6 traffic families
- **WHEN** the host materializes the secret-bearing execution lease for that
  path
- **THEN** the host-owned lease carries the family-complete tunnel state needed
  for that claim internally
- **AND** ordinary shell-facing reads still expose only typed planning or
  runtime state instead of raw carrier secrets

#### Scenario: IPv4-only execution lease does not imply dual-stack support

- **GIVEN** a strict `turn_datagram + wireguard_native` path whose host-owned
  execution lease only supports IPv4 tunnel state
- **WHEN** the host validates or reports support for that path
- **THEN** the repository keeps that path explicit as IPv4-only or incomplete
  for dual-stack claims
- **AND** it does not treat that lease as sufficient proof of IPv6-aware
  packaged system-tunnel support
