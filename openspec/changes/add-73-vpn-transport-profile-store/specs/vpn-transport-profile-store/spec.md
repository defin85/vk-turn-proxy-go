## ADDED Requirements

### Requirement: VPN transport profiles are first-class app-owned records

The system SHALL manage VPN transport material through app-owned, typed,
versioned transport profile records instead of treating a WireGuard `.conf`,
native file path, or raw secret blob as the generic product contract.

#### Scenario: Shell lists configured transport profiles

- **GIVEN** a compatible host with the VPN transport profile store capability
- **WHEN** a shell lists transport profiles
- **THEN** the host returns profile ids, profile kinds, display metadata,
  validation status, compatibility status, and supported actions
- **AND** the response does not include raw private keys, peer secrets, or
  host-private filesystem paths

#### Scenario: First concrete profile kind is WireGuard

- **GIVEN** the first packaged Android system-tunnel implementation requires
  WireGuard material
- **WHEN** the host stores that material
- **THEN** it stores a profile whose kind is `wireguard_native_v1`
- **AND** the profile store remains able to advertise other future profile
  kinds without redefining the base profile-store contract

### Requirement: Import adapters are separate from transport profile kinds

The system SHALL treat imported files, QR payloads, generated settings, or
native provider payloads as adapters that create or replace typed transport
profiles, not as the transport profile API itself.

#### Scenario: WireGuard conf import creates a typed profile

- **GIVEN** a shell imports a WireGuard `.conf` through a supported import
  adapter
- **WHEN** the host accepts the import
- **THEN** the host creates or replaces a `wireguard_native_v1` profile record
- **AND** subsequent startup references the profile id rather than the original
  `.conf` path or raw text
- **AND** acceptance requires parsing and validating the required WireGuard
  fields instead of trusting only the extension, picker filter, or display name

#### Scenario: Unsupported import format is rejected

- **GIVEN** a shell submits material through an import adapter that the current
  host does not advertise
- **WHEN** the host validates that import request
- **THEN** the host fails explicitly before storing material
- **AND** it does not guess a transport profile kind from the file extension or
  display name alone

### Requirement: Transport profile state stays redacted in ordinary reads

The system SHALL keep secret-bearing transport material out of ordinary profile
lists, startup results, events, diagnostics, and persisted shell state.

#### Scenario: Diagnostics describe a profile without leaking secrets

- **GIVEN** a configured VPN transport profile contains private keys or
  equivalent startable secrets
- **WHEN** the shell reads diagnostics or profile status
- **THEN** the host reports redacted status fields such as profile kind,
  validation result, compatibility result, last import time, and safe
  fingerprints where applicable
- **AND** it does not expose raw key material, preshared keys, complete peer
  secrets, or platform-private storage paths

#### Scenario: Secret material is excluded from platform backup by default

- **GIVEN** a platform storage backend persists a secret-bearing VPN transport
  profile
- **WHEN** the app participates in platform backup, migration, or sync features
- **THEN** the profile-store secret material is excluded unless a later
  reviewed encrypted export or backup contract is implemented
- **AND** ordinary backup/sync mechanisms do not become an undocumented
  cross-device profile transfer path

### Requirement: Transport profiles validate against execution plans

The system SHALL validate a selected transport profile against the requested
runtime execution plan before startup can report readiness.

#### Scenario: Required profile is missing

- **GIVEN** a runtime execution plan requires one of the advertised transport
  profile kinds
- **AND** no compatible configured profile is selected or available as a
  host-reported scoped default profile reference
- **WHEN** startup validation runs
- **THEN** startup fails closed before readiness is reported
- **AND** the failure identifies the missing transport profile prerequisite

#### Scenario: Configured profile is incompatible with the selected plan

- **GIVEN** a configured transport profile exists
- **AND** its kind, version, route material, endpoint assumptions, or required
  policy conflicts with the selected execution plan
- **WHEN** startup validation runs
- **THEN** startup fails closed with a typed incompatibility reason
- **AND** the host does not silently rewrite the profile, widen route scope, or
  substitute another engine family

### Requirement: Default transport profile selection is explicit and scoped

The system SHALL resolve any default transport profile through a host-reported,
profile-id-backed binding scoped to the selected host adapter and execution
plan.

#### Scenario: Default profile is visible before startup

- **GIVEN** a host has a default VPN transport profile for one execution plan
  and host adapter
- **WHEN** the shell reads profile-store status or execution-plan metadata
- **THEN** the host reports the selected default as a redacted profile
  reference
- **AND** the shell does not need to infer the default from filesystem state,
  package assets, environment variables, or import history alone

#### Scenario: Default profile for another plan is not reused

- **GIVEN** a profile is configured as the default for one host adapter or
  execution plan
- **WHEN** the operator starts a different plan that requires transport
  material
- **THEN** the host reuses that profile only if compatibility metadata says it
  is valid for the requested plan
- **AND** otherwise startup fails closed with a transport-profile prerequisite
  or incompatibility reason

### Requirement: Transport profile lifecycle is explicit and auditable

The system SHALL expose explicit lifecycle actions for importing, replacing,
forgetting, validating, and selecting VPN transport profiles.

#### Scenario: Operator forgets a configured profile

- **GIVEN** a VPN transport profile is configured
- **WHEN** the operator chooses the documented forget action
- **THEN** the host deletes or invalidates the secret-bearing material and
  associated default selection
- **AND** subsequent startup that requires that profile returns to setup-needed
  state

#### Scenario: Operator replaces a configured profile

- **GIVEN** a VPN transport profile is configured
- **WHEN** the operator imports replacement material through a supported
  adapter
- **THEN** the host validates and atomically replaces the profile material
- **AND** ordinary profile status reflects the replacement without exposing the
  old or new secret-bearing payload

#### Scenario: Legacy path-based material migrates once

- **GIVEN** a previous build stored explicit WireGuard material as a
  platform-private file path
- **WHEN** a profile-store-capable host starts for the first time
- **THEN** it may migrate that material into a `wireguard_native_v1` profile
  record exactly once
- **AND** after successful migration, startup uses the profile id rather than
  treating the legacy path as a second live source of truth
