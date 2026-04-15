## ADDED Requirements
### Requirement: Mobile GUI remains a typed consumer of Android VPN startup

The system SHALL keep the mobile GUI shell as a typed consumer of packaged-host
Android VPN startup rather than the owner of Android VPN primitives.

#### Scenario: Mobile GUI renders Android VPN workflow without owning `VpnService`

- **GIVEN** a production Android package whose packaged host reports the
  documented `android_vpn_service` mode
- **WHEN** the operator inspects or starts that mode from the mobile GUI
- **THEN** the UI renders capability, app-scope choice, and typed startup
  result state from the packaged host
- **AND** it does not implement its own direct `VpnService` lifecycle or
  Android route-application logic

### Requirement: Mobile GUI keeps system-tunnel UX adapter-driven rather than Android-API-driven

The system SHALL keep system-tunnel UX in the mobile shell tied to host-reported
mode metadata and typed startup results instead of Android API naming.

#### Scenario: Future mobile system-tunnel mode reuses the shell role

- **GIVEN** a future packaged mobile host that reports a different system-tunnel
  adapter from Android `VpnService`
- **WHEN** the mobile GUI renders that later mode
- **THEN** the shell can keep the same typed consumer role for capability,
  scope, and startup state
- **AND** it does not require a second UI architecture just because the native
  adapter is no longer Android-specific
