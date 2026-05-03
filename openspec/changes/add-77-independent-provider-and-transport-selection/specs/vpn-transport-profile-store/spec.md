## ADDED Requirements
### Requirement: VPN transport profiles remain independent from provider sources

The VPN transport profile store SHALL manage local engine material independently
from provider source, signaling, and resolved provider credentials.

#### Scenario: Shell lists local VPN transport profiles

- **GIVEN** a compatible host advertises VPN transport profile kinds such as
  `wireguard_native_v1` or future V2Ray, SOCKS5, Hysteria, or QUIC-derived
  kinds
- **WHEN** the shell renders the VPN transport profile catalog
- **THEN** each record is presented as local transport material with profile
  kind, validation, compatibility, and lifecycle status
- **AND** the catalog does not present VK TURN, WB TURN, Yandex Telemost, SFU,
  Rostelecom video paths, or other provider contours as VPN transport profile
  kinds
- **AND** selecting or editing a VPN transport profile does not implicitly
  select a provider source

#### Scenario: Transport profile does not store provider credentials

- **GIVEN** a provider resolution yields TURN credentials, room tokens, SFU
  attachment state, camera/player tokens, or another provider-owned secret
- **WHEN** a VPN transport profile is created, edited, selected, or validated
- **THEN** the transport profile record stores only local engine material and
  profile lifecycle metadata
- **AND** provider credentials remain in the provider-resolution or artifact
  layer rather than being copied into the transport profile store
