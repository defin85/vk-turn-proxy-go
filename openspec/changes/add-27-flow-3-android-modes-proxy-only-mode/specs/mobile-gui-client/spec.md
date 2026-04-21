## ADDED Requirements
### Requirement: Mobile GUI renders proxy-only mode as a separate Android workflow

The system SHALL let the mobile GUI present proxy-only mode separately from
`android_vpn_service`, including its explicit scope and endpoint details.

#### Scenario: Mobile GUI offers proxy-only mode

- **GIVEN** a mobile build whose packaged host reports the documented
  proxy-only Android mode
- **WHEN** the operator inspects Android runtime options in the app
- **THEN** the UI presents proxy-only mode separately from the system-tunnel
  workflow
- **AND** it renders the typed endpoint and scope information for that mode
- **AND** it does not describe the mode as device-wide capture
