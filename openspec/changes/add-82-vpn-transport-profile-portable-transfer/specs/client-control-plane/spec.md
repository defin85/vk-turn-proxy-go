## ADDED Requirements
### Requirement: Client control plane exposes typed transport-profile portable transfer actions

The system SHALL expose typed export, preview/import, and confirmation actions
for encrypted portable VPN transport-profile transfer instead of requiring
shells to read or write host-private store files directly.

#### Scenario: Shell requests encrypted transport-profile export

- **GIVEN** a compatible host advertises the VPN transport profile store and a
  configured profile supports the documented `export_portable` action
- **WHEN** a shell requests export for that profile and supplies the required
  transfer-passphrase input
- **THEN** the control plane returns an encrypted portable transport-profile
  envelope plus safe preview metadata
- **AND** it does not return raw private keys, raw peer secrets, or platform-
  private store paths in the ordinary API response

#### Scenario: Portable envelope uses one reviewed crypto profile

- **GIVEN** a shell requests portable export or preview/import for a VPN
  transport profile
- **WHEN** the host serializes or validates the encrypted envelope
- **THEN** the host uses the stable `portable_transport_profile` envelope type
  at version `1`
- **AND** passphrase-based encryption uses `Argon2id` key derivation plus
  `XChaCha20-Poly1305` authenticated encryption
- **AND** cleartext metadata remains limited to envelope type/version, profile
  kind, crypto-suite identifier, and decryption parameters such as salt and
  nonce
- **AND** the host rejects envelopes that declare unknown or weaker crypto
  suites or Argon2id parameters below the reviewed minimum floor

#### Scenario: Shell previews transport-profile import before confirmation

- **GIVEN** a shell supplies an encrypted portable transport-profile envelope
  and the required transfer passphrase through the control plane
- **WHEN** the host can decrypt and validate that payload
- **THEN** the control plane returns a typed preview describing the resulting
  profile kind, safe display metadata, compatibility result, whether selection
  is still required after import, and any non-blocking warnings
- **AND** it does not persist the imported secret-bearing profile material
  before explicit confirmation

#### Scenario: Duplicate preview points at the existing local profile

- **GIVEN** a shell supplies an encrypted portable transport-profile envelope
- **AND** the host can decrypt that payload successfully
- **AND** the decrypted canonical transport material already exists in one or
  more local profiles of the same kind
- **WHEN** the shell requests import preview
- **THEN** the control plane returns a typed `already_present` style preview
  instead of an import-confirmation payload
- **AND** that preview includes safe duplicate fingerprinting plus redacted
  references to the matching local profile record or records
- **AND** confirming a second identical local record is not part of the first
  shipped slice

#### Scenario: Name collision preview suggests a resolved local name

- **GIVEN** a shell supplies an encrypted portable transport-profile envelope
- **AND** the host can decrypt that payload successfully
- **AND** the transport material is importable but the imported display name
  collides with an existing local profile name
- **WHEN** the shell requests import preview
- **THEN** the control plane still returns an `importable` style preview
- **AND** that preview includes a non-blocking `display_name_conflict` warning
  plus the host-suggested resolved local display name
- **AND** the shell does not need to guess local naming rules on its own

#### Scenario: Wrong passphrase or unsupported envelope fails explicitly

- **GIVEN** a shell submits an encrypted transport-profile envelope through the
  control plane
- **WHEN** the passphrase is wrong, the envelope version is unsupported, or
  the destination host cannot accept the profile kind
- **THEN** the host returns an explicit typed failure before storing material
- **AND** it does not create a partial local profile or guess compatibility

#### Scenario: Confirmed import creates a new local transport profile record

- **GIVEN** a previewed transport-profile import is valid
- **WHEN** the shell confirms that import through the control plane
- **THEN** the host creates a fresh local transport profile record with a new
  local profile id
- **AND** the response reports ordinary redacted profile status rather than the
  decrypted secret-bearing payload
- **AND** it does not silently select that profile for startup unless the shell
  later requests the documented selection action

#### Scenario: Transfer secrets stay out of ordinary events and diagnostics

- **GIVEN** a shell submitted a transport-profile transfer passphrase or an
  encrypted portable transport-profile envelope through the control plane
- **WHEN** the host emits ordinary events, status snapshots, diagnostics, or
  logs
- **THEN** those surfaces exclude the submitted passphrase, decrypted
  transport-profile payload, and any derived transfer keys
- **AND** the shell does not need to redact those values from ordinary control-
  plane reads because the host never serializes them there
