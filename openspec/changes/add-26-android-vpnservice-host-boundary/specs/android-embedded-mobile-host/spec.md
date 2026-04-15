## ADDED Requirements
### Requirement: Android embedded host bridges the Go control plane to the Kotlin `VpnService` adapter

The system SHALL let the packaged Android embedded host coordinate the first
`android_vpn_service` path through a package-internal bridge to the Kotlin
`VpnService` adapter instead of routing VPN startup through Flutter-only logic.

#### Scenario: Packaged host starts Android VPN through the native adapter bridge

- **GIVEN** a production Android package with the documented embedded host and
  Android `VpnService` adapter
- **WHEN** the operator starts the Android system-tunnel workflow
- **THEN** the packaged embedded host reaches the native `VpnService` adapter
  through the documented package-internal bridge
- **AND** the app does not require an external sidecar host or shell-local VPN
  orchestration to reach the typed startup result
