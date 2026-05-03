## ADDED Requirements
### Requirement: Provider sources remain independent from VPN transport profiles

The system SHALL expose provider or contour sources as external artifact and
signaling choices rather than as VPN transport profile kinds.

#### Scenario: Shell lists external source contours

- **GIVEN** a compatible host and shell with several provider or contour source
  descriptors such as VK TURN, WB TURN, Yandex Telemost, SFU, or Rostelecom
  video paths
- **WHEN** the shell renders the provider source catalog
- **THEN** each source is presented as a provider or contour choice with
  artifact/access-method metadata
- **AND** the catalog does not present those choices as WireGuard, V2Ray,
  SOCKS5, Hysteria, QUIC, or another local VPN transport profile kind
- **AND** selecting a provider source does not implicitly select or create a
  VPN transport profile

#### Scenario: Provider record stores only provider-owned reusable settings

- **GIVEN** an operator creates or edits a reusable provider source record
- **WHEN** the shell persists that record
- **THEN** the record may store provider-owned reusable settings and safe
  display metadata
- **AND** it does not store local VPN transport secrets, raw profile material,
  host-private transport profile paths, or implicit VPN transport defaults
