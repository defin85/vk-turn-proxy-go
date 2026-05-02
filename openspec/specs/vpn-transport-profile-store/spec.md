# vpn-transport-profile-store Specification

## Purpose
Define the app-owned VPN transport profile store contract used by RelayDock
shells and hosts to persist, validate, redact, and select typed transport
profiles independently from provider-specific import material or startup
adapters.

## Requirements
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

### Requirement: VPN transport profiles support structured editing

The system SHALL let compatible hosts expose typed structured create and update
operations for supported VPN transport profile kinds instead of requiring every
profile to originate from an imported file.

#### Scenario: Host advertises editable WireGuard profile schema

- **GIVEN** a host supports structured editing for `wireguard_native_v1`
- **WHEN** a shell negotiates the VPN transport profile store capability
- **THEN** the host reports that `wireguard_native_v1` is editable
- **AND** it reports a schema version plus stable machine-readable field ids,
  value kinds, cardinality, and which fields are required, optional, secret,
  generated, update-preservable, or unsupported by the current materializer
- **AND** WireGuard `.conf` remains advertised only as an import adapter

#### Scenario: Operator creates profile without conf file

- **GIVEN** the host advertises structured editing for `wireguard_native_v1`
- **WHEN** the operator saves a complete structured WireGuard profile draft
- **THEN** the host creates a `wireguard_native_v1` transport profile record
- **AND** the returned status contains a stable profile id, redacted validation
  status, compatible execution plans, and safe display metadata
- **AND** subsequent startup uses the profile reference rather than raw form
  fields or a generated `.conf` path

### Requirement: Structured WireGuard fields are explicit and validated

The system SHALL validate structured `wireguard_native_v1` fields by name and
fail closed when required material is missing, malformed, or unsupported by the
current host.

#### Scenario: WireGuard draft contains required material

- **GIVEN** a structured WireGuard draft includes display metadata, at least one
  interface address, peer public key, allowed IPs, and either interface
  private-key material, an explicit host-generation request, or an explicit
  update request to preserve the existing host-owned private key
- **WHEN** the host validates the draft
- **THEN** it accepts only normalized values that can be materialized for the
  selected execution plan
- **AND** DNS servers, MTU, endpoint, and host-supported optional fields such as
  preshared key or persistent keepalive are preserved only when the host
  advertises support for those fields

#### Scenario: Unsupported field is rejected

- **GIVEN** a shell submits a structured field that the host did not advertise
  as supported for the profile kind
- **WHEN** the host validates the draft
- **THEN** validation fails with a field-specific error and a stable violation
  code such as `unknown`, `unsupported`, `required`, `malformed`, or
  `incompatible`
- **AND** the host does not silently store, ignore, or materialize that field

### Requirement: Structured edits keep secrets host-owned and redacted

The system SHALL keep secret-bearing structured profile fields out of ordinary
reads after create or update operations complete.

#### Scenario: Stored private key is not returned to the shell

- **GIVEN** a structured profile create or update stores WireGuard private-key
  material
- **WHEN** the shell lists profiles, reads status, exports diagnostics, or
  receives lifecycle events
- **THEN** the response omits the raw private key and equivalent secret fields
- **AND** it may include safe public-key metadata, redacted fingerprints, and
  validation messages that do not echo the secret value

#### Scenario: Host generates private key

- **GIVEN** the operator requests host-side key generation for a WireGuard
  transport profile
- **WHEN** the host creates or updates the profile
- **THEN** the host stores the generated private key as host-owned secret
  material
- **AND** the shell receives only safe public-key or fingerprint metadata
  needed to complete remote peer configuration

#### Scenario: Secret update intent is explicit

- **GIVEN** an existing `wireguard_native_v1` profile contains a host-owned
  private key
- **WHEN** the operator edits only non-secret fields
- **THEN** the structured update request carries an explicit
  `preserve_existing` action for the private-key field if the host advertised
  that action
- **AND** a create request or unsupported preserve action fails validation
  instead of silently storing an incomplete profile
- **AND** a manual replacement uses `replace_submitted` and is redacted from all
  subsequent ordinary reads

### Requirement: Structured updates are atomic

The system SHALL validate the complete resulting profile before replacing any
existing startable transport profile material.

#### Scenario: Invalid edit preserves previous profile

- **GIVEN** a compatible transport profile is currently selected for startup
- **WHEN** the operator submits an invalid structured update
- **THEN** the host rejects the update with field-aware validation errors
- **AND** the previous profile material, profile id, and default binding remain
  unchanged
- **AND** startup behavior remains based on the last valid profile

#### Scenario: Valid edit updates profile revision

- **GIVEN** a compatible transport profile is configured
- **WHEN** the operator submits a valid structured update
- **THEN** the host atomically replaces the stored profile material
- **AND** ordinary profile status reflects a new updated timestamp or revision
  without exposing raw secret material

### Requirement: Transport profile kinds are host-advertised and extensible

The VPN transport profile store SHALL treat profile kind values as
host-advertised capability data rather than as a WireGuard-only closed product
surface.

#### Scenario: Host advertises a future profile kind

- **GIVEN** a profile-store-capable host advertises an editable kind other than
  `wireguard_native_v1`
- **WHEN** a shell reads the transport profile store capability
- **THEN** the shell preserves the raw kind value and associated schema
  metadata
- **AND** it does not reject the entire host capability response only because
  the kind is unknown to the shell build
- **AND** it does not treat that kind as startable unless a compatible runtime
  execution plan and host adapter evidence are also advertised

#### Scenario: Unknown kind has no compatible runtime plan

- **GIVEN** a host advertises a transport profile kind that the shell can
  display from schema metadata
- **AND** no runtime execution plan declares that kind as a supported
  prerequisite
- **WHEN** the operator views setup state
- **THEN** the shell may show the profile kind as configurable or unsupported
  setup metadata
- **AND** VPN startup remains disabled with an explicit unavailable or
  setup-needed reason

### Requirement: Structured profile schemas are transport-neutral

The VPN transport profile store SHALL describe structured editable fields using
transport-neutral descriptors so shells can render profile editors without
hard-coding WireGuard fields.

#### Scenario: Host advertises a non-WireGuard structured schema

- **GIVEN** a host supports structured editing for a non-WireGuard profile kind
- **WHEN** it reports the editable schema
- **THEN** the schema lists stable field ids, value kinds, cardinality,
  required state, secret state, lifecycle actions, generation support, and
  update-preservation support for that kind
- **AND** the shell submits a field-value map and secret-action map keyed by
  those stable field ids
- **AND** unsupported or unknown submitted fields fail validation instead of
  being silently stored or ignored
- **AND** the host validates the resulting profile according to that kind's
  semantics before it becomes selectable for startup

#### Scenario: WireGuard schema remains one concrete schema

- **GIVEN** the host advertises `wireguard_native_v1`
- **WHEN** the shell renders its structured editor
- **THEN** WireGuard fields are rendered from the same schema descriptor
  mechanism as later profile kinds
- **AND** `.conf` import remains a WireGuard-specific import adapter rather
  than a generic VPN profile import path

#### Scenario: Schema uses unsupported value kind

- **GIVEN** a host schema contains a field value kind unsupported by the shell
  renderer
- **WHEN** the operator opens the profile setup surface
- **THEN** the shell reports structured editing as unsupported for that profile
  kind or field
- **AND** it offers only host-advertised fallback lifecycle actions that it can
  execute
- **AND** it does not submit partial, guessed, or defaulted values for the
  unsupported field

### Requirement: Multiple transport profiles remain explicitly selectable

The VPN transport profile store SHALL support multiple profile records without
turning kind, import history, or most-recent edit state into an implicit startup
selection.

#### Scenario: Host lists multiple compatible profiles

- **GIVEN** a host stores more than one VPN transport profile compatible with a
  selected execution plan
- **WHEN** the shell reads profile-store status
- **THEN** the host reports each profile with a stable profile id, kind,
  redacted validation status, compatibility status, and lifecycle actions
- **AND** startup uses only an explicit selected profile reference or
  host-reported scoped default binding
- **AND** the host does not infer startup selection from the last edited,
  imported, or displayed profile

#### Scenario: Operator selects profile for startup

- **GIVEN** multiple compatible transport profiles exist for one required kind
- **WHEN** the operator chooses one profile for startup or scoped default use
- **THEN** the shell invokes the host-advertised selection lifecycle action
- **AND** subsequent startup references the selected profile id
- **AND** incompatible profiles remain visible as status records but cannot be
  selected for that execution plan
