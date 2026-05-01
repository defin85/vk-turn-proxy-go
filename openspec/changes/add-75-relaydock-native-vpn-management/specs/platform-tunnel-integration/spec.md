## ADDED Requirements

### Requirement: Native Android VPN readiness requires RelayDock-owned evidence

The system SHALL treat native Android VPN support as ready only when the
packaged RelayDock app proves the direct `android_vpn_service` path without
depending on the external WireGuard Android application.

#### Scenario: Device smoke proves native RelayDock VPN readiness

- **GIVEN** a packaged Android RelayDock build with native
  `android_vpn_service` support
- **AND** a structured `wireguard_native_v1` profile and resolved TURN artifact
  are available
- **WHEN** the repo-owned Android device or emulator smoke starts VPN inside
  RelayDock
- **THEN** the smoke grants or resumes Android VPN permission through the
  RelayDock flow
- **AND** it observes a ready `android_vpn_service` session from the embedded
  host
- **AND** it can disconnect the session through RelayDock
- **AND** no step requires `com.wireguard.android`
- **AND** the smoke verifies the active VPN is the packaged RelayDock
  `VpnService` path rather than an external WireGuard tunnel

#### Scenario: Android system revokes native VPN readiness

- **GIVEN** RelayDock has reported a ready native `android_vpn_service` session
- **WHEN** Android revokes the VPN grant, another VPN app becomes prepared, or
  the service is stopped by the system
- **THEN** the platform tunnel state transitions away from ready
- **AND** runtime and native resources are cleaned up
- **AND** the next status check reports stopped or failed state with diagnostics

#### Scenario: External WireGuard compatibility does not satisfy native readiness

- **GIVEN** the external WireGuard Android application can route traffic through
  a RelayDock transport session
- **WHEN** native Android VPN support is evaluated
- **THEN** that compatibility result is recorded separately from native
  `android_vpn_service` readiness
- **AND** product readiness remains incomplete until RelayDock proves the direct
  native path

### Requirement: Library-backed native transport stays behind the platform tunnel boundary

The system SHALL allow library-backed native WireGuard, TUN, crypto, and
transport components only behind the platform tunnel host/native adapter
boundary.

#### Scenario: Native Android path uses a third-party transport library

- **GIVEN** the `android_vpn_service` implementation uses a native library for
  WireGuard, TUN, crypto, or packet transport
- **WHEN** the platform tunnel reports lifecycle state to the shell
- **THEN** the public contract remains the RelayDock platform-tunnel and
  control-plane contract
- **AND** the operator does not manage VPN through the library provider's own
  application or UI
