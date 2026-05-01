## ADDED Requirements

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
