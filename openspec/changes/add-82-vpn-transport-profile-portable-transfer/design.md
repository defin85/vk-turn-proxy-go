## Context

RelayDock now models native-VPN setup through two separate product records:

- saved shell profiles in the `Profiles` workspace
- host-owned VPN transport profiles in the dedicated transport-profile manager

That split is correct, but the current transfer surface is asymmetric.
Saved profiles already have explicit portable transfer across desktop and
mobile.
VPN transport profiles do not.

Live tablet inspection on May 8, 2026 showed the practical result:

- `VPS copy` exists as a saved profile and exposes `Export saved profile`
- `RelayDock VPS WireGuard 92.63.105.2` exists as a VPN transport profile and
  does not expose export
- importing only the saved profile onto another device is not enough for
  `android_vpn_service` startup, because the host still requires a compatible
  `wireguard_native_v1` transport profile

The current spec intentionally left room for this later step:

- ordinary backup/sync must not become an undocumented cross-device transfer
  path for secret-bearing transport material
- startup must fail closed when a required transport profile is missing

The new workflow therefore must add an explicit transfer contract without
collapsing the host-owned secret boundary or turning ordinary shell state into
another secret store.

## Goals

- Provide an explicit cross-device transfer workflow for VPN transport
  profiles.
- Keep secret-bearing transport-profile transfer encrypted and operator-driven.
- Keep the host as the owner of encryption, decryption, validation, storage,
  redaction, and compatibility decisions.
- Let desktop and mobile shells expose the same operator concept even if their
  share/file/QR adapters differ.
- Ship QR in the first encrypted transfer slice instead of leaving it as a
  later follow-up.
- Preserve fail-closed startup when a destination host still lacks a compatible
  imported or selected transport profile.

## Non-Goals

- Bundling saved profiles and VPN transport profiles into one combined export
  artifact in this change
- Turning platform backup, migration, or sync into a supported secret-transfer
  path
- Exposing raw private keys or other startable secret material through
  ordinary profile lists, status reads, or diagnostics
- Auto-selecting or auto-starting an imported transport profile without
  explicit operator action

## Decisions

### Decision: Transport-profile transfer stays separate from saved-profile transfer

Saved-profile portable transfer and VPN transport-profile transfer solve
different problems and carry different security weight.
Saved-profile transfer moves shell-owned workflow state.
Transport-profile transfer moves host-owned startable secret material.

This change keeps them as separate first-class workflows.
The operator may use both when moving a working setup between devices, but one
must not silently substitute for the other.

### Decision: The portable transport-profile envelope is encrypted and host-driven

The new transfer unit is an explicit encrypted portable transport-profile
envelope.
The shell does not serialize raw private keys or reimplement the envelope as
another shell-state file.
Instead, the host exposes typed export/import actions and produces or consumes
the encrypted envelope itself.

The shell may carry that encrypted envelope through file, share, text, or QR
adapters, but it treats the payload as opaque ciphertext plus safe display
metadata.

Portable transfer support must be machine-readable.
The shell must not infer transport-profile export/import support from generic
edit actions, from raw import adapters, or from the mere presence of
secret-bearing profiles.
Hosts must advertise dedicated portable-transfer capability metadata for the
supported transfer paths.

### Decision: Portable transfer uses one dedicated capability block plus one per-profile export action

`TransportProfileStoreCapability` grows a dedicated `portable_transfer`
capability block rather than overloading the existing generic
`lifecycle_actions` list or ordinary import-adapter metadata.

That block is the machine-readable source of truth for transport-profile
portable transfer and includes:

- `envelope_type = portable_transport_profile`
- `envelope_version = 1`
- `supported_kinds`
- `export_paths` and `import_paths` with stable path identifiers
  `text_payload`, `file_payload`, and `qr_payload`
- `qr_max_payload_bytes`
- `qr_mode = single_payload`

Per-profile availability of export remains explicit through a stable
`export_portable` action in `TransportProfileStatus.actions`.
Import remains a store-level capability and must not be inferred from the
presence of any local profile record.

### Decision: Export requires explicit sensitivity review and a transfer secret

Export is a documented secret-bearing action.
Before the host creates an encrypted envelope, the shell must present a
sensitivity warning and collect the operator's transfer secret.
The first shipped contract uses an operator-supplied transfer passphrase rather
than background key escrow or implicit device sync.

The shell must not persist that passphrase as ordinary shell state.
Ordinary control-plane reads, events, diagnostics, and logs must also exclude
the passphrase, decrypted payload, and any derived envelope keys.

### Decision: Portable transport-profile envelopes use one reviewed crypto profile

The first shipped portable transport-profile envelope uses one explicit crypto
profile:

- passphrase KDF: `Argon2id`
- content cipher: `XChaCha20-Poly1305`
- content key size: `256` bits

The encrypted envelope serializes the KDF parameters, salt, and AEAD nonce as
host-owned fields needed for decryption, and binds the authenticated data to
the declared envelope type, envelope version, profile kind, and crypto-suite
identifier.

Hosts must reject envelopes that declare unknown or weaker crypto suites.
Hosts must also reject Argon2id parameters below the reviewed minimum floor of
`memory_kib >= 65536`, `iterations >= 3`, and `parallelism >= 1`.

Safe cleartext metadata stays minimal and excludes operator-facing profile
details.
Outside ciphertext, the first shipped envelope may expose only:

- envelope type
- envelope version
- profile kind
- crypto-suite identifier
- KDF parameters
- salt and nonce material required for decryption

It does not expose display name, endpoint, fingerprint, peer keys, peer
addresses, or equivalent operator-visible profile material outside ciphertext.

### Decision: Import is preview-first and allocates a fresh local profile id

Import of a portable transport-profile envelope is always explicit.
The destination shell presents the encrypted payload to the host together with
the operator-supplied passphrase.
The host validates envelope version, decrypts, checks compatibility with the
current host, and returns a preview before import confirmation.

On confirmation, the destination host creates a fresh local transport profile
record.
It does not trust source-local ids, silently overwrite an unrelated local
profile, or auto-select the imported record as the scoped default unless the
operator explicitly requests that later through ordinary profile-selection
actions.

Before presenting an importable preview, the host also compares the decrypted
canonical transport material against existing local profiles of the same kind by
using a safe host-owned duplicate fingerprint.

If the host finds an exact local duplicate, the preview becomes an explicit
`already_present` result rather than an importable draft.
That duplicate preview includes redacted references to the matching local
profile record or records and whether one is already selected as the scoped
default for any applicable execution plan.

The first shipped slice does not create a second local profile record for exact
duplicates.
Instead, the shell routes the operator toward the existing record, including
ordinary later actions such as selecting that profile for startup when required.

### Decision: Preview outcomes are explicit and small in the first shipped slice

The first shipped portable-transfer preview model has three outcome families:

- `blocked`: the envelope cannot be accepted on this host because decryption,
  version, kind, or compatibility checks failed
- `already_present`: the decrypted canonical transport material exactly matches
  an existing local profile of the same kind
- `importable`: the envelope is valid for import on this host

The first shipped slice does not add fuzzy or heuristic "maybe related"
matching.
Only exact canonical duplicate detection changes the preview outcome from
`importable` to `already_present`.

`importable` previews may still carry non-blocking warnings.
The first such warning is `display_name_conflict`, which means the imported
profile name collides with an existing local profile name even though the
transport material is not an exact duplicate.

When `display_name_conflict` is present, the host returns a suggested resolved
local display name for the imported record.
The first shipped slice does not require an inline rename editor during import;
the operator may import with the suggested name and rename later through
ordinary profile-editing flows.

### Decision: Ordinary backup exclusion remains in force

This change satisfies the existing "later reviewed encrypted export contract"
escape hatch without weakening the ordinary backup rule.
Platform backup, migration, and sync still remain unsupported sources of
truth for transport-profile secret material.
Only the explicit encrypted transfer workflow becomes supported.

### Decision: QR is part of the first shipped path and stays bounded by encrypted payload size

The first shipped transport-profile transfer slice includes QR:

- desktop and mobile can render the encrypted envelope as QR when it fits
  within documented bounds
- mobile can scan that QR and submit the resulting encrypted envelope for
  preview/import

If the encrypted payload does not fit, shells fail closed for QR and keep
file/text/share paths available instead of truncating or weakening the
envelope.
The first shipped contract does not introduce multipart or chunked QR payloads.

## Risks / Trade-offs

- Passphrase-based transfer adds operator friction, but that is preferable to
  silently widening secret exposure.
- A host-driven envelope keeps the secret boundary cleaner, but requires typed
  preview/import/export operations instead of reusing the existing saved-profile
  envelope path.
- Keeping saved-profile and transport-profile transfer separate means moving a
  full working setup may take two explicit actions, but it avoids hiding which
  record carries startable secret material.
- Exact-duplicate suppression keeps the transport-profile store cleaner, but it
  requires one more preview outcome beyond simple importable-versus-invalid
  states.
- Automatic display-name disambiguation keeps the first import flow small, but
  it means the destination name may differ slightly from the source until the
  operator optionally renames it later.
- QR support is part of the first shipped path and is useful for
  desktop-to-mobile transfer, but some encrypted payloads may be too large; the
  workflow must fail closed when bounds are exceeded.

## Validation Plan

- Extend `vpn-transport-profile-store` with explicit encrypted portable
  transfer requirements while preserving ordinary backup exclusion.
- Lock the dedicated `portable_transfer` capability shape and the
  `export_portable` action instead of inferring support from generic actions.
- Extend `client-control-plane` with typed transport-profile export,
  preview/import, and confirmation actions.
- Lock one reviewed crypto profile and minimal cleartext metadata boundary for
  portable transport-profile envelopes.
- Extend mobile and desktop GUI specs so the VPN transport-profile manager and
  setup surfaces expose export/import as explicit secret-bearing actions.
- Treat desktop/mobile QR render plus mobile QR scan as required first-slice
  transfer paths, not as a later enhancement.
- Require implementation-time verification that destination startup still
  blocks on missing transport material and only becomes startable after the
  imported profile is present and selected.
- `openspec validate add-82-vpn-transport-profile-portable-transfer --strict --no-interactive`
