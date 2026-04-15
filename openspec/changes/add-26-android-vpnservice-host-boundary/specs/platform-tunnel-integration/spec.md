## ADDED Requirements
### Requirement: Android platform-tunnel startup may cross a packaged host boundary without splitting the contract

The system SHALL allow the documented Android `android_vpn_service` startup
path to cross a package-internal boundary between the embedded Go host and the
Kotlin `VpnService` adapter while keeping one typed platform-tunnel contract.

#### Scenario: Android host adapter succeeds but runtime attach still decides readiness

- **GIVEN** a packaged Android host whose Kotlin `VpnService` adapter can
  acquire permission and establish the Android VPN primitive
- **WHEN** the embedded Go host has not yet attached the documented runtime
  successfully
- **THEN** the repository does not claim `ready=true`
- **AND** readiness remains governed by the typed startup result from the
  packaged host boundary as a whole
- **AND** the cross-boundary startup path does not collapse that result into an
  adapter-local success bit

### Requirement: Cross-boundary platform-tunnel semantics stay reusable across native adapters

The system SHALL keep the cross-boundary platform-tunnel contract expressed in
typed startup semantics that later native adapters can reuse without inheriting
Android API names.

#### Scenario: Later packaged host uses a different native system-tunnel primitive

- **GIVEN** a later packaged host that uses a different native system-tunnel
  primitive from Android `VpnService`
- **WHEN** that host reuses the same platform-tunnel contract shape
- **THEN** readiness still depends on native bring-up plus runtime attach
- **AND** that reuse does not require the future native adapter to share the
  same process or service lifecycle as Android `VpnService`
- **AND** the shared contract does not require Android-only API objects to
  appear outside the native adapter boundary
