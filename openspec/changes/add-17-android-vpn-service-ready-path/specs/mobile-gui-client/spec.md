## MODIFIED Requirements
### Requirement: Mobile GUI system tunnel support remains explicit and host-driven

The system SHALL keep mobile GUI system tunnel support explicit and host-driven instead of implying it from app installation alone.
Installing the mobile app SHALL NOT silently claim device-wide traffic capture support, but the app MAY offer a documented workflow for a later packaged host mode such as `android_vpn_service` when that host explicitly reports the mode as supported.

#### Scenario: Mobile app still lacks a supported platform tunnel mode

- **GIVEN** a mobile app install whose connected host does not report a supported later platform tunnel mode
- **WHEN** the operator inspects platform support in the app
- **THEN** the app reports that system tunnel support is not yet available for that target
- **AND** it does not silently claim device-wide traffic capture

#### Scenario: Packaged Android host reports a supported `android_vpn_service` mode

- **GIVEN** a production Android package whose packaged host reports `android_vpn_service` as a supported platform tunnel mode
- **WHEN** the operator inspects platform support in the mobile GUI shell
- **THEN** the app offers the documented Android system tunnel workflow for that mode
- **AND** it uses the typed startup result instead of guessing support from OS heuristics alone
