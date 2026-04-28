## ADDED Requirements

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
