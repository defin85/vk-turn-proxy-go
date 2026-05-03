## ADDED Requirements
### Requirement: Desktop GUI separates provider sources from VPN transport profiles

The desktop GUI SHALL provide distinct workbench surfaces for provider sources
and VPN transport profiles while showing route or startup compatibility between
the two axes.

#### Scenario: Desktop operator manages source and transport in separate workspaces

- **GIVEN** the desktop shell exposes provider source choices such as VK TURN,
  WB TURN, Yandex Telemost, SFU, or Rostelecom video paths
- **AND** the desktop shell exposes VPN transport profile choices such as
  WireGuard, V2Ray, SOCKS5, Hysteria, or QUIC-derived profiles
- **WHEN** the operator opens the Providers or source workspace
- **THEN** that workspace focuses external provider/contour source records and
  source-specific setup
- **AND** it does not become the primary VPN transport profile manager
- **WHEN** the operator opens the VPN Transport Profiles workspace
- **THEN** that workspace focuses local transport profile lifecycle, redacted
  validation, compatibility, and selection
- **AND** it does not become the primary provider source catalog

#### Scenario: Desktop Routing explains the selected combination

- **GIVEN** the operator has selected or drafted one provider source and one
  VPN transport profile
- **WHEN** the desktop Routing or plan surface evaluates startup readiness
- **THEN** it shows the selected provider/source side, selected VPN transport
  profile side, and compatibility result as separate facts
- **AND** unsupported combinations remain inspectable with a precise missing
  provider, carrier, engine, host adapter, profile-kind, setup, degraded, or
  evidence reason
- **AND** the shell does not silently substitute either selected axis
