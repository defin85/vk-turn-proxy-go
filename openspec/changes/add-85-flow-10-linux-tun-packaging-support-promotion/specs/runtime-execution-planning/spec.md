## ADDED Requirements
### Requirement: Linux packaged system-tunnel support stays target-specific

The system SHALL promote `linux_tun` from unavailable to supported only for the
documented packaged Linux desktop target that satisfies the repo-owned install
surface and verification bar.

#### Scenario: Supported Ubuntu package reports `linux_tun`

- **GIVEN** a packaged Linux desktop host for the documented supported Ubuntu
  target
- **AND** that package includes the documented `linux_tun` helper and install
  surface
- **WHEN** the host reports packaged system-tunnel execution plans
- **THEN** it may report the strict TURN-backed `wireguard_native` `linux_tun`
  plan as supported
- **AND** other Linux targets remain unavailable until they satisfy their own
  documented package and verification bar
