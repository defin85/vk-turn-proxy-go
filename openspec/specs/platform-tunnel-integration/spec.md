# platform-tunnel-integration Specification

## Purpose
Define the typed capability, startup, and fail-closed reporting contract for platform-owned tunnel integrations across packaged hosts and GUI shells.
## Requirements
### Requirement: Platform tunnel support is capability-gated and explicit

The system SHALL expose platform tunnel support as an explicit, mode-specific capability instead of assuming that every host can capture system traffic.

#### Scenario: Host lacks required tunnel capability

- **GIVEN** a client shell running on a platform that lacks a required entitlement, permission, driver, or tunnel primitive
- **WHEN** the operator attempts to enable system-wide tunnel mode
- **THEN** the host reports the missing capability explicitly through the documented control-plane capability contract
- **AND** the report identifies the requested tunnel mode and the missing prerequisite
- **AND** the client does not silently fall back to a partial or undefined tunnel mode

#### Scenario: Host supports tunnel mode

- **GIVEN** a platform host that satisfies the documented tunnel prerequisites
- **WHEN** the client queries host capabilities
- **THEN** the host reports system tunnel support explicitly for the requested mode
- **AND** the report confirms that the documented prerequisites are satisfied
- **AND** the client may offer the documented tunnel workflow for that platform

### Requirement: Platform tunnel startup fails closed on unsafe routing prerequisites

The system SHALL validate route preparation and exclusion prerequisites before claiming system tunnel readiness.

#### Scenario: Required route exclusions are missing

- **GIVEN** a platform tunnel mode that requires explicit exclusion or bypass rules for control traffic
- **WHEN** startup validation finds that those exclusions are missing or invalid
- **THEN** startup fails before the client claims readiness
- **AND** the failure is surfaced as a documented platform tunnel startup error with the responsible startup stage

#### Scenario: Tunnel host starts safely

- **GIVEN** a platform host with the required tunnel capability and route prerequisites
- **WHEN** the operator starts system tunnel mode
- **THEN** the host establishes the documented tunnel path for that platform
- **AND** readiness is reported only after the host-specific tunnel prerequisites succeed

### Requirement: Platform tunnel startup surfaces stage-aware host failures

The system SHALL surface documented, stage-aware startup results from platform hosts instead of collapsing tunnel startup into a generic success or failure bit.

#### Scenario: Permission or entitlement is denied

- **GIVEN** a platform tunnel mode that requires user permission, entitlement, or a privileged extension
- **WHEN** startup cannot obtain that prerequisite
- **THEN** the host reports the documented startup stage and failing prerequisite explicitly
- **AND** the shell remains not ready for that tunnel mode

#### Scenario: Host cannot attach the runtime after tunnel setup

- **GIVEN** a platform host that has prepared routes and established the OS tunnel primitive
- **WHEN** the host cannot attach the shared client runtime to that tunnel path
- **THEN** startup fails with the documented host bring-up or runtime-attach stage
- **AND** the host tears down partial tunnel resources before returning failure

### Requirement: Platform tunnel integrations remain separate from provider behavior

The system SHALL keep OS-specific tunnel behavior and packet-capture mechanics separate from provider-specific signaling and credential resolution.

#### Scenario: Provider challenge occurs during a tunnel-capable client flow

- **GIVEN** a client profile that may later use platform tunnel mode
- **WHEN** provider resolution requires a browser challenge or other operator action
- **THEN** the provider challenge flow remains governed by the provider and control-plane contracts
- **AND** the platform tunnel integration does not add hidden provider-specific fallback behavior

#### Scenario: Platform host owns route and packet-capture mechanics

- **GIVEN** a supported platform tunnel mode
- **WHEN** the host establishes packet capture and route handling for that mode
- **THEN** those OS-specific mechanics remain inside the platform host or extension boundary
- **AND** the shared runtime receives traffic through the documented host boundary instead of embedding platform-specific tunnel APIs

### Requirement: Platform tunnel support claims are execution-plan-specific

The system SHALL scope platform tunnel support claims to the documented runtime execution plans that a packaged host actually supports for that mode.
Support for one packaged system-tunnel plan SHALL NOT imply support for another engine or carrier family on the same host adapter.

#### Scenario: Supported platform tunnel mode does not imply non-TURN execution

- **GIVEN** a packaged host that supports one documented platform tunnel mode through a TURN-backed `wireguard_native` execution plan
- **WHEN** the client queries platform tunnel support for that mode
- **THEN** the host reports support only for that documented execution plan
- **AND** it does not imply that `webrtc_datachannel`, `proxy_core_adapter`, `trusttunnel_native`, or another carrier or engine family is also supported on that same host adapter

#### Scenario: Packaged host lacks the requested execution plan

- **GIVEN** a platform tunnel mode whose host adapter exists on the current build
- **AND** the current build does not satisfy the documented execution-plan prerequisites for the requested carrier or engine family
- **WHEN** startup validation checks that plan
- **THEN** startup fails before `ready=true`
- **AND** the failure keeps the unsupported execution plan explicit instead of falling back to a guessed system-tunnel path

### Requirement: Platform tunnel readiness depends on the documented carrier as well as the host adapter

The system SHALL require the documented strict carrier and execution
materialization prerequisites for a packaged `wireguard_native` platform tunnel
mode in addition to the OS-specific tunnel primitive.

#### Scenario: Host adapter exists but the strict WireGuard carrier is missing

- **GIVEN** a packaged host can acquire the OS tunnel primitive for one
  platform mode such as `android_vpn_service` or `windows_wintun`
- **AND** the host does not implement the documented strict `turn_datagram`
  `wireguard_native` carrier or its execution-materialization step
- **WHEN** startup validates the requested execution plan for that mode
- **THEN** startup fails before `ready=true`
- **AND** the failure keeps the requested execution plan explicit
- **AND** the host does not silently reuse the current overlay runtime as if it
  were the same platform-tunnel path

#### Scenario: Packaged host reaches ready state only after strict carrier attach

- **GIVEN** a packaged host has prepared routes and established the OS tunnel
  primitive for one strict `wireguard_native` mode
- **WHEN** the host attaches the documented strict `turn_datagram`
  `wireguard_native` carrier successfully
- **THEN** readiness is reported only after that carrier attach succeeds
- **AND** the host may claim support for that mode only on builds that satisfy
  both the adapter and carrier prerequisites

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

### Requirement: Platform tunnel startup accepts explicit underlay-route policies

The system SHALL treat application-routing scope and underlay-route preservation
as separate startup concerns for supported platform tunnel modes.

#### Scenario: Android system tunnel preserves the active local network for development

- **GIVEN** a supported `android_vpn_service` host
- **AND** the caller requests the typed underlay-route policy
  `preserve_active_local_network`
- **WHEN** platform tunnel startup prepares routes for that mode
- **THEN** the host preserves the active local underlay network outside the
  tunnel for development or control traffic
- **AND** the mode remains the documented Android system-tunnel mode rather
  than a different runtime mode
- **AND** application-routing policy continues to apply independently of the
  underlay-route policy

#### Scenario: Standard profile keeps normal route preparation

- **GIVEN** a supported platform tunnel mode
- **WHEN** the caller uses the default underlay-route policy
  `standard`
- **THEN** startup keeps the normal route-preparation behavior for that mode
- **AND** it does not imply local-network preservation unless the caller
  requested it explicitly

### Requirement: Platform tunnel startup fails closed for unsupported underlay-route policies

The system SHALL reject unsupported or unsafe underlay-route policy requests
explicitly instead of silently downgrading them.

#### Scenario: Host does not support the requested underlay-route policy

- **GIVEN** a caller requests a typed underlay-route policy that the current
  host does not advertise for the requested mode
- **WHEN** startup validation runs
- **THEN** startup fails closed with an explicit typed failure
- **AND** the host does not silently replace the request with `standard`

#### Scenario: Requested local-network preservation cannot be prepared safely

- **GIVEN** the caller requests `preserve_active_local_network`
- **WHEN** the host cannot determine or apply the required route exclusions for
  the active underlay network
- **THEN** startup fails before readiness is reported
- **AND** the failure identifies route preparation or route exclusion as the
  responsible prerequisite

### Requirement: Platform tunnel ready state reflects an attached runtime session

The system SHALL treat `ready=true` for a runtime-backed platform-tunnel mode
as proof that the packaged host attached the shared runtime successfully, and
SHALL surface that runtime through the ordinary session contract.

#### Scenario: Host reaches ready for a runtime-backed platform tunnel

- **GIVEN** a packaged host starts one supported platform-tunnel mode
- **AND** the host completes permission, route validation, host bring-up, and
  runtime attach successfully
- **WHEN** startup reports `ready=true`
- **THEN** the resulting runtime is visible through the ordinary typed session
  surface
- **AND** tunnel-stage detail remains available through the startup result or
  diagnostics instead of replacing the session surface

#### Scenario: Host fails before runtime-backed readiness

- **GIVEN** a packaged host starts one supported platform-tunnel mode
- **WHEN** startup fails before runtime attach reaches ready state
- **THEN** the host does not claim a ready runtime session for that attempt
- **AND** the host still reports the failing tunnel stage and cleanup outcome
  through the documented platform-tunnel result

### Requirement: Android packaged hosts can establish a ready `android_vpn_service` path

The system SHALL support one concrete platform tunnel ready path for packaged Android hosts through `android_vpn_service`.

#### Scenario: Packaged Android host reaches ready state

- **GIVEN** an Android package that includes the documented `android_vpn_service` implementation and route policy for the supported target
- **AND** the operator grants the required VPN permission
- **WHEN** the operator starts system tunnel mode for `android_vpn_service`
- **THEN** startup returns `ready=true` for `android_vpn_service`
- **AND** the host reports readiness only after route validation, host bring-up, and runtime attach succeed
- **AND** the mobile shell may treat that mode as supported for that packaged target

#### Scenario: Operator denies Android VPN permission

- **GIVEN** a packaged Android host that requires VPN permission before `android_vpn_service` can start
- **WHEN** the operator denies that permission during startup
- **THEN** startup returns `ready=false`
- **AND** it reports `permission_acquire` as the failing stage
- **AND** it reports `permission` as the missing prerequisite

#### Scenario: Android startup resumes after permission grant

- **GIVEN** a packaged Android host that paused `android_vpn_service` startup
  at the VPN permission prerequisite
- **WHEN** the operator grants that permission and the shell resumes the
  documented startup attempt
- **THEN** the packaged host continues the same startup flow instead of asking
  the shell to rebuild Android tunnel state from scratch
- **AND** readiness still depends on later route validation, host bring-up, and
  runtime attach success

### Requirement: Android `android_vpn_service` startup protects control traffic and cleans up on failure

The system SHALL validate Android route exclusion and DNS bypass policy before claiming readiness, and SHALL tear down partial Android VPN resources when startup fails after partial progress.

#### Scenario: Control-traffic exclusion or DNS bypass is unsafe

- **GIVEN** an Android packaged host starting `android_vpn_service`
- **AND** the documented control-plane, provider-challenge, or required underlay exclusions cannot be applied safely
- **WHEN** startup validates the Android route policy
- **THEN** startup returns `ready=false`
- **AND** it reports `route_validate` as the failing stage
- **AND** it reports `route_exclusion` or `dns_bypass` as the missing prerequisite
- **AND** the host does not claim readiness

#### Scenario: Runtime attach fails after Android VPN bring-up

- **GIVEN** an Android packaged host that has already created the VPN interface and prepared the documented route policy
- **WHEN** the host cannot attach the shared runtime to that `android_vpn_service` path
- **THEN** startup returns `ready=false`
- **AND** it reports `runtime_attach` as the failing stage
- **AND** the host tears down the partial Android VPN resources before returning failure

### Requirement: Android `android_vpn_service` app-routing policy is explicit and fail-closed

The system SHALL treat Android app-routing scope as an explicit startup policy
for the first `android_vpn_service` path instead of assuming that every Android
VPN mode captures all apps equally.

#### Scenario: Packaged Android host starts with an explicit selected-app policy

- **GIVEN** a packaged Android host starting `android_vpn_service`
- **AND** the documented startup request chooses one supported
  `application_routing_policy` such as `all_apps`, `allowed_packages`, or
  `disallowed_packages`
- **WHEN** startup validates route and package policy together
- **THEN** the host applies that documented app-scope policy before claiming
  readiness
- **AND** the mobile shell can report whether the mode covers all apps or only
  the selected app set

#### Scenario: Android app-routing policy is invalid or mixed

- **GIVEN** a startup request for `android_vpn_service`
- **AND** the request mixes allowlist and denylist package semantics, or names
  one or more invalid packages
- **WHEN** the packaged Android host validates startup prerequisites
- **THEN** startup returns `ready=false`
- **AND** it reports `route_validate` as the failing stage
- **AND** it reports `app_routing_policy` as the missing prerequisite
- **AND** the host does not silently widen the scope to full-device routing

#### Scenario: Operator changes Android app scope after readiness

- **GIVEN** an Android packaged host whose `android_vpn_service` path is already
  ready with one documented `application_routing_policy`
- **WHEN** the operator changes the requested package scope for that mode
- **THEN** the repository treats that change as a new startup attempt and VPN
  connection instead of a live mutation of the existing ready path
- **AND** the shell does not imply that the running Android VPN scope changed
  without that reconnect

### Requirement: Desktop platform tunnel support is claimed per packaged target and mode

The system SHALL claim desktop platform tunnel support only for the packaged desktop target and typed mode that actually satisfies the documented prerequisites.
A supported ready path on one desktop OS SHALL NOT silently imply support for another desktop OS or mode.

#### Scenario: Windows readiness does not imply other desktop readiness

- **GIVEN** a production Windows desktop package that is documented as supporting a ready `windows_wintun` path
- **AND** a different desktop target still lacks its own documented ready-path implementation such as `linux_tun` or `apple_network_extension`
- **WHEN** the operator inspects platform tunnel capability on that other desktop target
- **THEN** the host reports that target mode as unsupported or missing its prerequisite
- **AND** the shell does not claim generic desktop system tunnel support from the Windows evidence alone

#### Scenario: Desktop target reports support only for its satisfied mode

- **GIVEN** a packaged desktop target whose host satisfies the documented prerequisites for one desktop platform tunnel mode
- **WHEN** the client queries host capabilities
- **THEN** the host reports support explicitly for that mode only
- **AND** the report confirms the documented prerequisites are satisfied

### Requirement: Packaged Windows hosts can establish the first desktop ready `windows_wintun` path

The system SHALL support the first concrete desktop platform tunnel ready path for packaged Windows hosts through `windows_wintun`.

#### Scenario: Packaged Windows host reaches ready state

- **GIVEN** a Windows desktop package that includes the documented `windows_wintun` implementation and packaged host
- **AND** the target machine satisfies the documented driver, privilege, and strict carrier materialization prerequisites
- **WHEN** the operator starts system tunnel mode for `windows_wintun`
- **THEN** startup returns `ready=true` for `windows_wintun`
- **AND** the host reports readiness only after driver validation, route preparation, host bring-up, and runtime attach succeed

#### Scenario: Wintun prerequisite is missing

- **GIVEN** a packaged Windows host that cannot satisfy a documented `windows_wintun` prerequisite such as driver availability, required privilege, or strict carrier materialization input
- **WHEN** the operator starts system tunnel mode for `windows_wintun`
- **THEN** startup returns `ready=false`
- **AND** it reports `capability_check` or `driver_check` as the failing stage
- **AND** it reports the missing prerequisite explicitly

### Requirement: Desktop ready-path startup protects underlay control traffic and cleans up on failure

The system SHALL validate desktop route exclusion and DNS bypass policy before claiming readiness for any supported desktop mode, and SHALL tear down partial desktop tunnel resources when startup fails after partial progress.
The first supported Windows path SHALL satisfy this rule for TURN underlay, control-plane, provider-challenge, and DNS flows.

#### Scenario: Desktop control-traffic exclusion is unsafe

- **GIVEN** a packaged desktop host starting a supported platform tunnel mode
- **AND** the documented TURN underlay, control-plane, provider-challenge, or DNS bypass exclusions cannot be applied safely
- **WHEN** startup validates the documented desktop route policy for that mode
- **THEN** startup returns `ready=false`
- **AND** it reports `route_validate` as the failing stage
- **AND** it reports `route_exclusion` or `dns_bypass` as the missing prerequisite
- **AND** the host does not claim readiness

#### Scenario: Runtime attach fails after Windows host bring-up

- **GIVEN** a packaged Windows host that has already created the documented Wintun adapter and prepared the route policy
- **WHEN** the host cannot attach the shared runtime to that `windows_wintun` path
- **THEN** startup returns `ready=false`
- **AND** it reports `runtime_attach` as the failing stage
- **AND** the host tears down the partial Windows tunnel resources before returning failure

### Requirement: Desktop platform-tunnel startup may cross a packaged host boundary without splitting the contract

The system SHALL allow documented desktop system-tunnel startup to cross a
packaged host boundary between the Go control plane and an OS-specific native
desktop adapter while keeping one typed platform-tunnel contract.

#### Scenario: Native desktop adapter succeeds but runtime attach still decides readiness

- **GIVEN** a packaged desktop host whose native adapter can acquire the OS
  tunnel primitive for one documented desktop mode
- **WHEN** the Go control plane has not yet attached the documented runtime
  successfully
- **THEN** the repository does not claim `ready=true`
- **AND** readiness remains governed by the typed startup result from the
  packaged host boundary as a whole

### Requirement: Cross-boundary desktop semantics stay reusable across native adapters

The system SHALL keep the cross-boundary desktop platform-tunnel contract
expressed in typed startup semantics that later desktop adapters can reuse
without inheriting one OS adapter's API names.

#### Scenario: Later packaged desktop host uses a different native system-tunnel primitive

- **GIVEN** a later packaged desktop host that uses a different native
  system-tunnel primitive from the first shipped desktop mode
- **WHEN** that host reuses the same platform-tunnel contract shape
- **THEN** readiness still depends on native bring-up plus runtime attach
- **AND** the shared contract does not require one OS adapter's API objects to
  appear outside the native adapter boundary

### Requirement: Platform tunnel readiness includes transport profile prerequisites

The system SHALL treat required VPN transport profile validation as a platform
tunnel prerequisite, alongside native adapter bring-up, route policy, and
runtime attach.

#### Scenario: Native adapter exists but profile material is missing

- **GIVEN** a packaged host can bring up a native tunnel adapter such as
  `android_vpn_service` or `windows_wintun`
- **AND** the requested execution plan requires a transport profile that is not
  configured or compatible
- **WHEN** startup validates platform tunnel prerequisites
- **THEN** startup fails before `ready=true`
- **AND** the failure identifies the missing or incompatible transport profile
- **AND** the failure uses the typed `transport_profile` prerequisite rather
  than a generic host implementation prerequisite
- **AND** the host does not claim readiness from native adapter availability
  alone

#### Scenario: Transport profile is validated before runtime attach

- **GIVEN** a selected platform tunnel mode, execution plan, and transport
  profile reference
- **WHEN** the host starts that mode
- **THEN** it validates the profile against the plan before reporting readiness
- **AND** readiness remains gated on native bring-up plus successful runtime
  attach after profile validation

#### Scenario: Profile validation failure does not trigger native cleanup

- **GIVEN** a platform tunnel startup request fails during transport profile
  validation
- **WHEN** the host returns the startup failure
- **THEN** the host has not yet created native tunnel resources that require
  route or adapter cleanup
- **AND** cleanup remains required only for failures after native bring-up or
  route mutation begins

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

### Requirement: Platform tunnel readiness is profile-kind specific

Platform tunnel readiness SHALL be evaluated against the selected runtime
execution plan and the concrete VPN transport profile kind required by that
plan.

#### Scenario: Future profile kind lacks native adapter evidence

- **GIVEN** a host can store or edit a future VPN transport profile kind
- **AND** the packaged native adapter has not proven startup for an execution
  plan requiring that kind
- **WHEN** platform tunnel readiness is evaluated
- **THEN** readiness remains unavailable or setup-needed
- **AND** the host does not claim that a WireGuard-ready adapter proves support
  for the future kind

#### Scenario: Concrete new transport proves readiness later

- **GIVEN** a later change implements a concrete non-WireGuard VPN transport
  profile kind
- **WHEN** that change claims platform tunnel readiness
- **THEN** it includes repo-owned host/native adapter evidence for start,
  status recovery, diagnostics, and disconnect through RelayDock
- **AND** it keeps external application workflows separate from RelayDock
  native readiness claims

### Requirement: Transport profile schemas do not own platform routing policy

The system SHALL keep platform tunnel routing policy, app scope, underlay
socket protection, and VPN permission lifecycle as platform-tunnel adapter
responsibilities rather than implicit behavior hidden inside transport profile
schemas.

#### Scenario: Profile schema includes route-like material

- **GIVEN** a transport profile schema includes engine material that resembles
  route, allowed-app, DNS, MTU, or endpoint configuration
- **WHEN** the host evaluates platform tunnel startup
- **THEN** the host applies app scope, route scope, underlay socket protection,
  and Android VPN permission state from the platform tunnel contract
- **AND** it does not let profile material silently override RelayDock routing
  or app-scope policy
- **AND** conflicts fail closed with a typed prerequisite or policy error

### Requirement: Platform tunnel readiness exposes remote ingress diagnostics

The platform tunnel startup/status contract SHALL expose the selected remote
ingress protocol, address, and isolation for strict
`turn_datagram + wireguard_native` readiness.

#### Scenario: Ready strict WireGuard result names raw ingress

- **GIVEN** a packaged platform tunnel host reaches `ready=true` for a strict
  `turn_datagram + wireguard_native` plan
- **WHEN** the host returns the startup result or current platform tunnel status
- **THEN** `remote_ingress.protocol` is `raw_wireguard_datagram` or a verified
  UDP protocol multiplexer
- **AND** `remote_ingress.address` names the selected ingress address
- **AND** `remote_ingress.isolation` identifies whether the endpoint is
  dedicated or mux-backed
- **AND** the shell can display those diagnostics without exposing WireGuard
  secret material

#### Scenario: Ready strict Windows Wintun result names data-plane evidence

- **GIVEN** a packaged Windows Wintun host reaches `ready=true` for a strict
  `turn_datagram + wireguard_native` plan
- **WHEN** the host returns the startup result or current platform tunnel status
- **THEN** `dataplane.host_attached` is `true`
- **AND** `dataplane.wireguard_handshake_fresh` is `true`
- **AND** `dataplane.wireguard_rx_bytes_delta`,
  `dataplane.wireguard_tx_bytes_delta`, and
  `dataplane.wintun_received_bytes_delta` are positive
- **AND** `dataplane.remote_egress_ip` identifies the public VPS egress IP
- **AND** `dataplane.bidirectional_traffic_verified` is `true`

