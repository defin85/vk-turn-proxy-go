## ADDED Requirements
### Requirement: Packaged desktop hosts own supported desktop ready paths

The system SHALL let the packaged desktop host own every supported desktop platform tunnel lifecycle so production desktop installs can start the documented system tunnel mode without an external VPN companion app or operator-managed route commands.

#### Scenario: Unsupported desktop target stays fail-closed

- **GIVEN** a production desktop package whose bundled host does not yet implement a documented ready path for the current desktop target
- **WHEN** the operator requests desktop system tunnel startup
- **THEN** the packaged host reports the typed failing stage and missing prerequisite explicitly
- **AND** the desktop app fails closed for that target instead of redirecting the operator to an undefined external host workflow

#### Scenario: Packaged Windows host starts the documented first desktop tunnel path

- **GIVEN** a production Windows desktop package with the documented bundled host and `windows_wintun` implementation
- **WHEN** the operator starts the packaged desktop system tunnel workflow
- **THEN** the packaged host owns driver preparation, route preparation, packet capture, and runtime attach for that mode
- **AND** the operator does not need an external `WireGuard for Windows` client or manual `route add` commands to reach the typed startup result
