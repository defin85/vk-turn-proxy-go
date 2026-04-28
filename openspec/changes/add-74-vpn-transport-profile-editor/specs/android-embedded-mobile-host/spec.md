## ADDED Requirements

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
