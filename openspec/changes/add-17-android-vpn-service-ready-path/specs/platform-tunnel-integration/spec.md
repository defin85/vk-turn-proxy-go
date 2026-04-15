## ADDED Requirements
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
