# android-vpnservice-host-boundary Specification

## Purpose
TBD - created by archiving change add-26-android-vpnservice-host-boundary. Update Purpose after archive.
## Requirements
### Requirement: Packaged Android VPN delivery keeps Flutter, Kotlin, and Go ownership separate

The system SHALL deliver the first repo-owned Android `VpnService` path with an
explicit ownership split across Flutter UI, Kotlin/Android, and the embedded Go
host.

#### Scenario: Operator starts Android system tunnel from the mobile UI

- **GIVEN** a packaged Android build that includes the documented
  `android_vpn_service` path
- **WHEN** the operator starts that mode from the Flutter UI
- **THEN** Flutter acts as a typed consumer of capability, app-scope, and
  startup result state
- **AND** the UI does not directly own Android VPN permission, `VpnService`, or
  packet-capture lifecycle

### Requirement: Kotlin owns Android OS VPN primitives

The system SHALL keep Android-specific VPN primitives inside the Kotlin/Android
adapter boundary.

#### Scenario: Android package applies VPN permission and package policy

- **GIVEN** a packaged Android host starting the documented `android_vpn_service`
  mode
- **WHEN** startup acquires permission and applies package allow/deny policy
- **THEN** those Android-native operations are owned by the Kotlin
  `VpnService` boundary
- **AND** the repository does not require Flutter widgets or Go transport code
  to manipulate `VpnService.Builder` directly

### Requirement: Embedded Go host remains the canonical orchestrator

The system SHALL keep typed startup orchestration, execution-plan ownership, and
runtime attach under the embedded Go host contract even when Android VPN bring-up
uses native Android code.

#### Scenario: Android adapter returns startup state to the packaged host

- **GIVEN** a packaged Android host starting the documented system-tunnel mode
- **WHEN** the Android-native `VpnService` adapter completes or fails a startup
  stage
- **THEN** the embedded Go host remains the canonical source of typed startup
  result state
- **AND** the app does not expose a second independent Android-only tunnel API
  to the shell

### Requirement: Shared ownership boundaries stay reusable while native adapters remain platform-specific

The system SHALL keep the first Android `VpnService` boundary reusable at the
ownership level without leaking Android API names into shared Flutter or Go
contracts.

#### Scenario: Future packaged mobile system-tunnel mode uses a different native adapter

- **GIVEN** a future packaged mobile host that uses a different native system
  tunnel primitive such as `apple_network_extension`
- **WHEN** the repository reuses the packaged ownership split from this change
- **THEN** Flutter still acts as a typed consumer and the embedded Go host
  still acts as the canonical orchestrator
- **AND** only the native adapter implementation changes
- **AND** a future adapter may use a different process or extension lifecycle
  from Android `VpnService`
- **AND** the shared boundary does not require Android `VpnService` types to be
  present in Flutter or Go code

