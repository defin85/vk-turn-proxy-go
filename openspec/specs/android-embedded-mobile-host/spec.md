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

