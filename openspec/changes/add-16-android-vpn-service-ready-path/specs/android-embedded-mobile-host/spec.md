## ADDED Requirements
### Requirement: Android embedded host owns the first `android_vpn_service` ready path

The system SHALL let the packaged Android embedded host own the first supported `android_vpn_service` lifecycle so production installs can start the documented Android system tunnel mode without an external companion runtime.

#### Scenario: Packaged host starts the documented Android VPN path

- **GIVEN** a production Android package with the documented embedded host and `android_vpn_service` implementation
- **WHEN** the operator starts the packaged Android system tunnel workflow
- **THEN** the packaged host owns the permission, route, and runtime-attach workflow for that mode
- **AND** the app does not require an external `clientd`, external bridge endpoint, or host download to reach the typed startup result

#### Scenario: Packaged host cannot satisfy the Android VPN prerequisites

- **GIVEN** a production Android package whose packaged host cannot satisfy a documented `android_vpn_service` prerequisite
- **WHEN** the operator requests Android system tunnel startup
- **THEN** the packaged host reports the typed failing stage and missing prerequisite explicitly
- **AND** the app fails closed for that mode instead of redirecting the operator to a development bridge path
