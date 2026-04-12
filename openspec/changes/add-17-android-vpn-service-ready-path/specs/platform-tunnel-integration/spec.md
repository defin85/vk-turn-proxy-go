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
