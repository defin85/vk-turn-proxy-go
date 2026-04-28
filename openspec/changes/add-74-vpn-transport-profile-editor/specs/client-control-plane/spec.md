## ADDED Requirements

### Requirement: Client control plane exposes structured profile editing

The client control plane SHALL expose versioned structured create, update,
validation preview, and key-generation operations for VPN transport profile
kinds that advertise editable schemas.

#### Scenario: Shell discovers editable profile kinds

- **GIVEN** a shell negotiates with a profile-store-capable host
- **WHEN** the host supports structured editing for a profile kind
- **THEN** the host capability metadata identifies the editable kind, supported
  fields, lifecycle actions, and redaction guarantees
- **AND** the shell suppresses structured editor actions for profile kinds or
  fields that the host does not advertise

#### Scenario: Shell creates or updates profile through structured payload

- **GIVEN** the host advertises structured editing for `wireguard_native_v1`
- **WHEN** the shell submits a structured create or update request
- **THEN** the request names the profile kind explicitly
- **AND** the response returns a redacted `TransportProfileStatus`
- **AND** the response does not include raw private keys, host-private storage
  paths, or generated config files

### Requirement: Client control plane reports structured field errors safely

The client control plane SHALL return field-aware validation failures for
structured profile drafts without leaking secret-bearing submitted values.

#### Scenario: Structured draft has invalid field values

- **GIVEN** a structured WireGuard draft has an invalid address, key, endpoint,
  MTU, allowed IP, or unsupported optional field
- **WHEN** validation fails
- **THEN** the control plane returns a typed validation error that identifies
  the affected field
- **AND** any message is redacted so it does not echo private keys, preshared
  keys, or equivalent secret-bearing values

#### Scenario: Validation preview does not mutate profile store

- **GIVEN** the shell previews validation for a structured profile draft
- **WHEN** the draft is invalid or incompatible
- **THEN** the host returns validation diagnostics without creating or updating
  a stored profile
- **AND** existing profile status and startup defaults remain unchanged
