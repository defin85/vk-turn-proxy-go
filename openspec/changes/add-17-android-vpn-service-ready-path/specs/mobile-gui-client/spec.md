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

### Requirement: Mobile GUI shell renders explicit Android app-scope policy

The system SHALL let the mobile GUI render the supported Android
`android_vpn_service` app-scope policy explicitly instead of implying that the
mode always captures all apps.

#### Scenario: Operator selects which apps the Android VPN mode should cover

- **GIVEN** a production Android package whose packaged host reports the
  documented `android_vpn_service` mode and its supported
  `application_routing_policy` values
- **WHEN** the operator enables Android system tunnel mode from the mobile GUI
- **THEN** the app can present the supported scope choices such as all apps or
  selected package sets
- **AND** it sends that scope choice through the typed host contract instead of
  reinterpreting package policy locally

#### Scenario: Mobile GUI does not present Android VPN mode as stealth

- **GIVEN** a production Android package whose packaged host reports a
  supported `android_vpn_service` mode
- **WHEN** the operator inspects or starts that mode in the mobile GUI
- **THEN** the app presents it as a documented Android system tunnel workflow
- **AND** it does not describe that mode as hidden from Android diagnostics or
  platform-visible VPN state

#### Scenario: Mobile GUI treats Android app-scope changes as reconnect-required

- **GIVEN** a production Android package whose packaged host reports a
  supported `android_vpn_service` mode
- **AND** the operator has already started that mode with one explicit
  app-scope selection
- **WHEN** the operator changes the requested app-scope policy or selected
  package set
- **THEN** the app treats that change as reconnect-required startup input
- **AND** it does not claim that the running Android VPN scope mutated in place
