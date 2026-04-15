## ADDED Requirements
### Requirement: Mobile GUI keeps Android runtime modes separate

The system SHALL present Android system-tunnel and future non-system relay
modes as separate operator-facing workflows instead of collapsing them into one
generic toggle.

#### Scenario: Mobile GUI offers a documented Android system-tunnel mode

- **GIVEN** a mobile build whose packaged host reports a supported
  `android_vpn_service` mode
- **WHEN** the operator inspects Android runtime options
- **THEN** the UI presents that mode as a documented system-tunnel workflow
- **AND** it does not imply that the mode is equivalent to a future proxy-only
  or non-system relay path

#### Scenario: Mobile GUI later exposes a non-system Android mode

- **GIVEN** a future mobile build that adds a documented non-system Android
  relay mode
- **WHEN** the operator inspects Android runtime options
- **THEN** the UI presents that mode separately from the system-tunnel mode
- **AND** it identifies the mode-specific scope and prerequisites explicitly
