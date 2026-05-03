## ADDED Requirements
### Requirement: Mobile GUI separates provider sources from VPN transport profiles

The mobile GUI SHALL provide distinct operator workflows for provider sources
and VPN transport profiles while letting startup combine compatible choices
through runtime execution planning.

#### Scenario: Operator chooses provider and VPN transport independently

- **GIVEN** the mobile shell has provider source choices such as VK TURN, WB
  TURN, Yandex Telemost, SFU, or Rostelecom video paths
- **AND** the shell has VPN transport profile choices such as WireGuard, V2Ray,
  SOCKS5, Hysteria, or QUIC-derived profiles
- **WHEN** the operator chooses a provider source and a VPN transport profile
- **THEN** those choices remain separately editable from their respective
  mobile destinations or manager pages
- **AND** the shell shows compatibility, setup-needed, degraded, or unsupported
  state for the selected combination before enabling startup
- **AND** the shell does not hide the transport profile choice inside the
  provider source editor or hide the provider source choice inside the VPN
  transport profile editor

#### Scenario: Mobile Home starts only validated combinations

- **GIVEN** mobile Home remains the primary VPN connect and disconnect owner
- **WHEN** the selected provider source and VPN transport profile combination
  is unsupported, missing setup, degraded without approval, or missing evidence
- **THEN** Home shows the relevant blocked or setup-needed state
- **AND** it offers links to the provider source or VPN transport profile
  manager according to the failing axis
- **AND** it does not auto-select a different provider source or profile to make
  the primary action available
