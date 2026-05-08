## ADDED Requirements
### Requirement: VPN transport profiles support explicit encrypted portable transfer

The system SHALL support an explicit encrypted portable transfer workflow for
secret-bearing VPN transport profiles without turning ordinary persistence,
backup, or sync into a supported secret-transfer path.

#### Scenario: Operator exports an encrypted transport-profile envelope

- **GIVEN** a configured VPN transport profile whose lifecycle actions include
  the documented portable export action
- **WHEN** the operator explicitly requests transport-profile export and
  provides the required transfer passphrase
- **THEN** the host produces an encrypted portable transport-profile envelope
- **AND** the shell receives only ciphertext plus safe display metadata needed
  for operator review and transfer routing
- **AND** the host does not expose raw private keys, peer secrets, or
  equivalent startable material through ordinary profile status reads

#### Scenario: Portable transfer support is advertised explicitly

- **GIVEN** a host supports encrypted portable transfer for one or more VPN
  transport profile kinds
- **WHEN** a shell reads transport-profile capability or profile status
- **THEN** the host advertises a dedicated `portable_transfer` capability block
  with stable machine-readable `supported_kinds`, `export_paths`,
  `import_paths`, `qr_max_payload_bytes`, and `qr_mode` fields
- **AND** the host uses a stable `export_portable` action on applicable
  profile-status records to mark per-profile export availability
- **AND** the shell does not guess portable transfer support from ordinary
  import adapters, edit actions, or the mere presence of secret-bearing
  transport profiles

#### Scenario: Destination host imports an encrypted transport-profile envelope

- **GIVEN** a destination host that supports the imported transport-profile
  kind
- **AND** the operator provides a portable transport-profile envelope plus the
  required transfer passphrase
- **WHEN** the host validates and decrypts that envelope
- **THEN** it returns an explicit preview before storing secret-bearing
  material
- **AND** after confirmation it creates a fresh local VPN transport profile
  record with a new local profile id
- **AND** it does not silently overwrite an unrelated local profile or trust
  source-local ids

#### Scenario: Exact duplicate import resolves to the existing local record

- **GIVEN** a destination host can decrypt a portable transport-profile envelope
- **AND** the decrypted canonical transport material matches one or more local
  profiles of the same kind
- **WHEN** the host prepares the import preview
- **THEN** it returns an explicit duplicate result with safe duplicate
  fingerprinting and redacted references to the matching local profile records
- **AND** it does not offer that payload as an importable second record in the
  first shipped slice
- **AND** ordinary later actions such as profile selection continue to target
  the existing local record

#### Scenario: Name collision does not block a distinct import

- **GIVEN** a destination host can decrypt a portable transport-profile envelope
- **AND** the transport material is not an exact duplicate of any local profile
- **AND** the imported display name collides with an existing local profile
  name
- **WHEN** the host prepares the import preview
- **THEN** it keeps the preview importable
- **AND** it reports a non-blocking `display_name_conflict` warning plus a
  suggested resolved local display name
- **AND** on confirmation it creates a fresh local profile record under the
  suggested resolved name unless the reviewed contract later adds an explicit
  rename step

#### Scenario: Imported transport profile is not auto-selected

- **GIVEN** a destination host successfully imported a compatible VPN transport
  profile from a portable envelope
- **WHEN** the import completes
- **THEN** the imported profile remains an ordinary local profile-store record
- **AND** any scoped default binding or startup selection still requires an
  explicit later operator action
- **AND** startup continues to fail closed until a compatible profile is
  selected when the execution plan requires it

#### Scenario: Ordinary backup exclusion still applies after portable export

- **GIVEN** a host supports explicit encrypted portable transport-profile
  export
- **WHEN** the app participates in ordinary platform backup, migration, or
  sync features
- **THEN** secret-bearing transport-profile material remains excluded from
  those ordinary platform mechanisms
- **AND** the reviewed portable export workflow does not authorize silent or
  background cross-device secret transfer
