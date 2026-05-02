## ADDED Requirements

### Requirement: Mobile GUI provides RelayDock-native VPN management

The mobile GUI SHALL let the operator manage the supported native Android VPN
lifecycle inside RelayDock when the packaged host advertises
`android_vpn_service`.

#### Scenario: Operator starts the native VPN path inside RelayDock

- **GIVEN** the packaged Android host advertises `android_vpn_service`
- **AND** a structured `wireguard_native_v1` profile is configured
- **AND** a resolved TURN artifact is available for startup
- **WHEN** the operator starts VPN from the mobile shell
- **THEN** the shell requests native startup through the control plane
- **AND** the shell drives any required Android VPN permission and resume flow
- **AND** the shell shows ready state only after the host reports a ready
  `android_vpn_service` session
- **AND** the shell shows state from host/control-plane lifecycle rather than
  treating a local button result as permanent VPN truth
- **AND** the shell does not redirect the operator to the external WireGuard
  Android application

#### Scenario: Missing native profile stays in RelayDock setup

- **GIVEN** the packaged Android host advertises `android_vpn_service`
- **AND** no startable structured VPN transport profile exists
- **WHEN** the operator attempts to configure the native VPN path
- **THEN** the shell opens the RelayDock profile setup/edit flow
- **AND** `.conf` import remains an in-app adapter into the same structured
  profile store
- **AND** `Routing` may link to the native VPN profile setup flow but does not
  embed the generic TURN/runtime profile editor as a routing control
- **AND** `Routing` does not duplicate the primary VPN start or disconnect
  action owned by `Home`
- **AND** the shell does not require profile setup in an external WireGuard
  Android application

#### Scenario: Operator disconnects the native VPN path inside RelayDock

- **GIVEN** the mobile shell shows a ready `android_vpn_service` session
- **WHEN** the operator chooses the primary disconnect action
- **THEN** the shell sends the stop request through the control plane
- **AND** the shell updates to stopped or failed state from host lifecycle
  events
- **AND** the shell keeps session diagnostics reachable for the completed
  attempt

#### Scenario: Shell recovers native VPN state after foreground return

- **GIVEN** the operator returns to RelayDock after Android or another VPN app
  changed the active VPN state
- **WHEN** the mobile shell refreshes native VPN status
- **THEN** the shell queries the host/control-plane lifecycle state
- **AND** it reflects ready, stopped, failed, revoked, or setup-needed state
  from the host
- **AND** it does not keep showing a stale ready state from a previous
  shell-local action

### Requirement: Mobile GUI excludes external WireGuard app evidence from native acceptance

The mobile GUI SHALL NOT present the external WireGuard Android application as
the product path for native VPN management.

#### Scenario: External WireGuard app is installed

- **GIVEN** `com.wireguard.android` is installed on the device
- **AND** the packaged RelayDock host advertises `android_vpn_service`
- **WHEN** the mobile shell presents native VPN setup or start controls
- **THEN** the shell keeps controls inside RelayDock
- **AND** any external WireGuard-app state is ignored for native VPN readiness
  claims
