# android-embedded-mobile-host Specification

## Purpose
Define the packaged Android embedded-host contract and the rules for bridging the canonical client-control semantics into the mobile app.
## Requirements
### Requirement: Android app package includes a compatible embedded host

The system SHALL package a compatible Android embedded host with the mobile app so production installs do not depend on an external runtime binary, sidecar, or first-run host download.

#### Scenario: First launch without network bootstrap

- **GIVEN** an Android app install on a device with no prior local host state
- **WHEN** the operator launches the app for the first time
- **THEN** the packaged embedded host is the runtime source used by the mobile GUI shell
- **AND** the app does not require downloading or locating an external client binary before session control can start

### Requirement: Android embedded host preserves canonical control-plane semantics

The system SHALL expose the Android embedded host through the existing mobile host semantics so profile, session, challenge, diagnostics, build identity, and compatibility behavior remain consistent with the canonical repository runtime.

#### Scenario: GUI negotiates capabilities against packaged host

- **GIVEN** an Android app with a packaged embedded host
- **WHEN** the mobile GUI shell initializes its host bridge
- **THEN** the packaged host reports the expected control-plane contract and required capabilities
- **AND** the GUI fails closed if the packaged host is missing or incompatible

### Requirement: Development bridge overrides stay non-default on Android

The system SHALL treat external Android bridge endpoints as explicit development overrides rather than the default production runtime model.

#### Scenario: Production package lacks a usable packaged host

- **GIVEN** an Android production package where the packaged host cannot bootstrap successfully
- **WHEN** the mobile GUI shell starts
- **THEN** the app reports the packaged-host failure explicitly
- **AND** it does not silently fall back to a development bridge endpoint

#### Scenario: Development build targets an external bridge

- **GIVEN** an Android development build with a documented external bridge override
- **WHEN** the operator runs that build for debugging or compatibility work
- **THEN** the app may use the explicit override instead of the packaged host
- **AND** that path remains a development-only exception to the production packaging model

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
- **AND** the mobile shell still reaches that startup only through the
  documented mobile host bridge and versioned control-plane contract rather
  than a direct adapter-specific API

### Requirement: Android embedded host can preserve the active local network for development-safe VPN startup

The system SHALL let the packaged Android embedded host prepare an explicit
development underlay-route profile for `android_vpn_service` startup while
keeping the mode itself a normal Android system tunnel.

#### Scenario: Host starts Android VPN with development local-network preservation

- **GIVEN** the packaged Android host supports the typed underlay-route policy
  `preserve_active_local_network`
- **AND** the device has an active local underlay network
- **WHEN** the mobile GUI requests Android VPN startup with that policy
- **THEN** the host computes and applies the required local-network route
  exclusions for that active network
- **AND** the packaged runtime still starts through the documented Android VPN
  host boundary

#### Scenario: Host cannot prepare the requested development profile

- **GIVEN** the mobile GUI requests `preserve_active_local_network`
- **WHEN** the packaged Android host cannot determine or safely apply the
  active local-network exclusion set
- **THEN** startup fails closed before readiness is reported
- **AND** the app does not silently fall back to the standard routing profile

#### Scenario: Host surfaces effective development underlay-route state

- **GIVEN** Android VPN startup succeeded with a typed underlay-route policy
- **WHEN** the shell inspects host-reported status or diagnostics
- **THEN** the host reports the selected underlay-route policy and the fact
  that local-network preservation was applied
- **AND** diagnostics can distinguish that state from the standard routing
  profile

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

### Requirement: Android embedded host owns `VpnService` app-scope policy

The system SHALL let the packaged Android embedded host own package allow/deny
policy for the first `android_vpn_service` path instead of pushing that logic
into shell heuristics.

#### Scenario: Packaged host applies an allowed-package policy

- **GIVEN** a production Android package with the documented embedded host and
  `android_vpn_service` implementation
- **WHEN** the operator starts the Android system tunnel workflow for one
  selected package set
- **THEN** the packaged host applies the documented package allow/deny policy
  through the Android host boundary
- **AND** the shell remains a typed consumer of the resulting startup state

#### Scenario: Packaged host cannot apply the requested app-scope policy

- **GIVEN** a production Android package whose packaged host cannot satisfy the
  requested package allow/deny policy for `android_vpn_service`
- **WHEN** startup validates that app-scope policy
- **THEN** the packaged host reports the typed failing stage and missing
  prerequisite explicitly
- **AND** it does not silently widen or narrow the operator-requested scope

### Requirement: Android embedded host owns transport profile storage and materialization

The Android embedded host SHALL store, validate, and materialize Android VPN
transport profiles through host-owned profile records instead of exposing
app-private file paths or raw profile text as shell-visible startup inputs.

#### Scenario: Android host imports WireGuard material as a profile

- **GIVEN** the mobile shell imports WireGuard material through the documented
  profile-store action
- **WHEN** the Android embedded host accepts the import
- **THEN** the host stores it as a `wireguard_native_v1` transport profile
- **AND** the shell receives only redacted profile status and a stable profile
  reference
- **AND** the shell does not need to know the app-private filesystem path used
  by the Android storage backend

#### Scenario: Android host materializes startup from a profile reference

- **GIVEN** a selected `android_vpn_service` execution plan requires a
  `wireguard_native_v1` transport profile
- **AND** the shell requests startup with a compatible profile reference or the
  host has reported a scoped default profile reference for that exact plan
- **WHEN** the embedded host prepares startup
- **THEN** it materializes the WireGuard runtime input internally from the
  host-owned profile record
- **AND** it does not read `phone1.conf`, workstation-local seed assets, or
  environment fallback paths

#### Scenario: Android legacy app-private file migrates into a profile record

- **GIVEN** an upgraded Android package finds the previous explicit
  app-private WireGuard file created before the profile store existed
- **WHEN** the embedded host initializes the profile store
- **THEN** it migrates the file into a `wireguard_native_v1` profile record or
  reports a redacted validation failure
- **AND** successful startup after migration uses the profile id rather than
  keeping the file path as a shell-visible contract

### Requirement: Android profile store forgets secret material fail-closed

The Android embedded host SHALL make profile deletion or invalidation return
dependent startup paths to setup-needed state.

#### Scenario: Operator forgets Android WireGuard profile

- **GIVEN** an Android `wireguard_native_v1` transport profile is configured
- **WHEN** the operator invokes the documented forget action
- **THEN** the embedded host removes or invalidates the stored secret material
- **AND** subsequent `android_vpn_service` startup requiring that profile fails
  closed before VPN readiness is reported

### Requirement: Android embedded host stores structured VPN profiles

The Android embedded host SHALL persist structured VPN transport profiles in
the same host-owned no-backup profile store used for imported transport
profiles.

#### Scenario: Structured profile persists across host restart

- **GIVEN** the mobile shell creates a structured `wireguard_native_v1`
  transport profile
- **WHEN** the Android embedded host restarts
- **THEN** the host reloads the profile as redacted profile status
- **AND** the host can materialize startup from its profile id
- **AND** raw private-key material is not exposed through shell-visible status,
  diagnostics, or native bridge method payloads

#### Scenario: Invalid structured edit does not replace stored Android profile

- **GIVEN** an Android `wireguard_native_v1` transport profile is configured
- **WHEN** the shell submits an invalid structured update
- **THEN** the host rejects the update before writing the no-backup store
- **AND** subsequent Android VPN Service startup still uses the last valid
  profile if one was previously selected

### Requirement: Android embedded host supports host-side key generation

The Android embedded host SHALL provide host-side key generation for editable
WireGuard transport profiles when the structured editor advertises that action.

#### Scenario: Host generates private key for mobile profile

- **GIVEN** the operator requests a generated WireGuard key while creating or
  updating a mobile VPN transport profile
- **WHEN** the Android embedded host accepts the request
- **THEN** it stores the private key as host-owned material in the no-backup
  store
- **AND** it returns only safe public-key or fingerprint metadata to the shell

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

