## ADDED Requirements

### Requirement: Android embedded host owns native VPN lifecycle from structured profiles

The packaged Android embedded host SHALL own the native
`android_vpn_service` lifecycle from selected structured profile and resolved
runtime artifact to ready, stopped, or failed state.

#### Scenario: Host attaches a structured profile and resolved artifact

- **GIVEN** a selected startable `wireguard_native_v1` profile in the host-owned
  store
- **AND** a resolved TURN artifact is available for the requested session
- **WHEN** the control plane requests native `android_vpn_service` startup
- **THEN** the embedded host materializes the structured profile into the
  library-backed native runtime inputs
- **AND** it invokes the package-internal Android VPN adapter
- **AND** it reports ready only after the runtime is attached to
  `android_vpn_service`

#### Scenario: Host tears down native VPN resources on stop

- **GIVEN** a ready native `android_vpn_service` session
- **WHEN** the control plane requests stop
- **THEN** the embedded host stops the runtime session
- **AND** it tears down the native `VpnService`, TUN, route, DNS, and protected
  socket resources owned by the attempt
- **AND** it reports an inactive lifecycle state for the stopped attempt

#### Scenario: Host handles Android VPN revocation

- **GIVEN** a ready native `android_vpn_service` session
- **WHEN** Android revokes RelayDock's VPN grant, a different VPN application
  becomes prepared, or the system stops the service
- **THEN** the embedded host treats the event as a lifecycle transition
- **AND** it closes the runtime session and native resources owned by the
  attempt
- **AND** it reports a stopped or failed state with actionable diagnostics
- **AND** it does not keep reporting native VPN readiness from stale state

#### Scenario: Missing native prerequisites fail closed

- **GIVEN** a native `android_vpn_service` startup request
- **AND** the selected profile, resolved artifact, route policy, DNS bypass,
  app-scope policy, native library, or runtime attach prerequisite is missing
- **WHEN** startup reaches the missing prerequisite
- **THEN** the embedded host rejects or fails the attempt at the corresponding
  stage
- **AND** it does not report native VPN readiness
- **AND** it does not fall back to the external WireGuard Android application

### Requirement: Android embedded host may use libraries without ceding product control

The packaged Android embedded host SHALL keep library-backed WireGuard, TUN,
crypto, and transport implementation details behind the host/native adapter
boundary.

#### Scenario: Native implementation uses a WireGuard library

- **GIVEN** the native VPN path uses an established WireGuard or TUN library
- **WHEN** the operator starts, monitors, or disconnects VPN from RelayDock
- **THEN** RelayDock remains the owner of lifecycle, state, diagnostics, and
  error reporting
- **AND** no third-party operator UI is required for the native path

### Requirement: Android embedded host declares system-managed VPN support honestly

The packaged Android embedded host SHALL explicitly support or opt out of
Android system-managed VPN lifecycle features that can start or stop VPN
outside the normal RelayDock button flow.

#### Scenario: Packaged host does not support always-on VPN

- **GIVEN** the packaged host cannot start the native VPN path from stored state
  without interactive provider resolution or shell-owned transient input
- **WHEN** the Android manifest declares the RelayDock `VpnService`
- **THEN** the service opts out of always-on VPN support
- **AND** RelayDock product UI and diagnostics do not claim always-on behavior

#### Scenario: Packaged host supports always-on VPN

- **GIVEN** a future packaged host claims always-on VPN support
- **WHEN** Android starts the VPN service without a foreground shell action
- **THEN** the host reconstructs the required selected profile, artifact or
  refresh path, route policy, app scope, runtime attach, and diagnostics from
  durable state
- **AND** failure is reported through the same host/control-plane lifecycle
  semantics as operator-started VPN

#### Scenario: Active native VPN is system-visible

- **GIVEN** the native `android_vpn_service` path is starting or ready
- **WHEN** RelayDock owns the active Android VPN service
- **THEN** the native adapter runs with the required foreground service
  notification and system-visible VPN state
- **AND** the notification or system configure action returns the operator to
  RelayDock rather than a third-party VPN UI
