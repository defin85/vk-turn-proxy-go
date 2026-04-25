## ADDED Requirements

### Requirement: Desktop platform-tunnel app-routing support claims are enforcement-specific

The system SHALL NOT treat support for a desktop platform-tunnel adapter as
support for desktop application routing unless the host also advertises a
verified app classifier or enforcement layer for that adapter.

#### Scenario: Desktop adapter exists without app-routing enforcement

- **GIVEN** a desktop host supports a platform-tunnel adapter such as
  `windows_wintun`
- **AND** the host does not have a verified app classifier or enforcement layer
  for that adapter
- **WHEN** the shell queries platform tunnel capabilities
- **THEN** the host may report the adapter according to its existing readiness
  contract
- **AND** it reports desktop app routing as unsupported for that adapter
- **AND** startup rejects desktop app-routing selectors for that adapter

#### Scenario: Desktop app-routing prerequisites are satisfied

- **GIVEN** a desktop host has a supported platform-tunnel adapter and a
  verified app classifier or enforcement layer for the same mode
- **WHEN** the host reports platform tunnel capabilities
- **THEN** desktop app-routing support is reported as a separate capability
  with its own prerequisites and policy kinds
- **AND** readiness for an app-routed startup is reported only after both
  platform-tunnel and app-routing prerequisites succeed
