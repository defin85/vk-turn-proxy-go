## ADDED Requirements
### Requirement: Local host exposes provider resolution as a typed handoff resource

The system SHALL expose provider resolution as a typed local host resource that
is separate from runtime session startup.

#### Scenario: Shell starts a provider resolution attempt

- **GIVEN** a compatible local host and a provider input such as a VK invite or
  another supported provider link
- **WHEN** a local shell requests provider resolution
- **THEN** the host creates a stable resolution identifier and returns a typed
  resolution record
- **AND** the record moves through documented states such as `starting`,
  `challenge_required`, `resolved`, `failed`, `cancelled`, or `expired`
- **AND** no transport runtime session is started implicitly just because
  provider resolution began

#### Scenario: Resolution requires operator challenge continuation

- **GIVEN** a provider resolution attempt that reaches a challenge boundary
- **WHEN** the local shell inspects the typed resolution state
- **THEN** the host exposes a stable challenge identifier and typed challenge
  metadata for that resolution
- **AND** the shell can continue or cancel the challenge without parsing human
  log output

### Requirement: Successful resolution supports explicit generic-turn export

The system SHALL allow explicit export of a short-lived `generic-turn://...`
handoff link only when provider resolution yields transport-ready TURN
credentials together with authoritative expiry information, whether that
information is surfaced directly by the provider result or derived through a
committed repository-owned provider-specific parser contract.

#### Scenario: Successful resolution is exported explicitly

- **GIVEN** a resolution record in `resolved` state whose provider output
  includes transport-ready TURN credentials
- **WHEN** the shell explicitly requests export for that resolution
- **THEN** the host returns a complete `generic-turn://<username>:<password>@<host>:<port>`
  handoff link together with the corresponding expiry information
- **AND** the host does not require the shell to reconstruct the link from
  partial fields on its own
- **AND** the exported handoff remains valid only until the reported expiry
  rather than claiming a stronger single-use guarantee

#### Scenario: Repository-derived provider expiry qualifies for export

- **GIVEN** a resolution record in `resolved` state whose provider output
  includes transport-ready TURN credentials
- **AND** the repository defines a committed provider-specific parser contract
  that derives expiry from those credentials without guessing
- **WHEN** the shell explicitly requests export for that resolution
- **THEN** the host may return the complete `generic-turn://...` handoff link
  together with the derived expiry information
- **AND** the host records that the expiry came from the provider-specific
  parser contract rather than a guessed timeout
- **AND** the export contract remains fail-closed once that derived expiry is
  reached

#### Scenario: Provider expiry is unknown

- **GIVEN** a resolution record in `resolved` state whose provider output
  yields transport-ready TURN credentials but does not include authoritative
  expiry semantics and does not match any repository-owned provider-specific
  parser contract
- **WHEN** the shell requests export
- **THEN** the host fails explicitly
- **AND** it does not mint a guessed `expires_at` value
- **AND** it does not claim cross-device handoff support for that resolution

#### Scenario: Ordinary reads stay redacted

- **GIVEN** a successful resolution record
- **WHEN** the shell lists resolutions, reads one resolution, consumes events,
  or exports diagnostics without an explicit export action
- **THEN** raw TURN credentials and the full `generic-turn://...` link are not
  exposed
- **AND** the host surfaces only redacted or non-secret metadata needed for UX
  or support

#### Scenario: Non-ready provider output cannot be exported

- **GIVEN** a resolution record that is still `starting`, still
  `challenge_required`, `failed`, `cancelled`, `expired`, or otherwise lacks
  transport-ready TURN credentials
- **WHEN** the shell requests export
- **THEN** the host fails explicitly
- **AND** it does not synthesize a partial or guessed `generic-turn` link

### Requirement: Successful resolution can materialize the same-device product path

The system SHALL allow a local shell to materialize a successful provider
resolution into the supported same-device runtime path without mandatory manual
secret copy/paste.

#### Scenario: Desktop starts on the same device from a resolved handoff

- **GIVEN** a successful resolution record and an explicit non-secret
  operator-managed runtime-defaults payload for the supported desktop product
  path
- **WHEN** the desktop shell requests same-device materialization or startup for
  that resolution
- **THEN** the host creates or updates the target product runtime input from the
  resolved credentials
- **AND** the resulting startup path uses the same supported product runtime
  surface as a normal `generic-turn` session on that host

#### Scenario: Materialization defaults stay separate from saved secret profiles

- **GIVEN** a shell that persists operator-managed runtime defaults for the
  materialize action
- **WHEN** the shell requests same-device materialization
- **THEN** the request carries only non-secret runtime defaults such as listen
  address, peer address, transport policy, and similar runtime knobs
- **AND** the host does not require a saved profile that contains the derived
  provider secret
- **AND** the materialize action does not silently persist a new secret-bearing
  profile as a side effect

#### Scenario: Materialization does not weaken secret redaction

- **GIVEN** a successful same-device materialization
- **WHEN** the shell later reads profiles, sessions, diagnostics, or ordinary
  resolution state
- **THEN** the host still does not expose raw provider-resolved TURN credentials
  by default
- **AND** explicit export remains the only way to obtain the full secret
  `generic-turn` handoff link for copy/share purposes
- **AND** the host does not silently convert the resolved secret into a new
  long-lived saved profile by default

### Requirement: Desktop and mobile shells consume one platform-neutral handoff contract

The system SHALL let desktop and mobile shells consume the same typed
resolution-handoff contract while keeping platform-specific UX outside the host
and provider layers.

#### Scenario: Desktop offers same-device startup plus optional export

- **GIVEN** a desktop shell connected to a compatible host
- **WHEN** a resolution reaches `resolved`
- **THEN** the desktop shell can offer a same-device startup action through the
  typed host contract
- **AND** it may also offer an explicit export or copy action without inventing
  provider-specific credential formatting

#### Scenario: Mobile offers explicit cross-device handoff actions

- **GIVEN** a mobile shell connected to a compatible host
- **WHEN** a resolution reaches `resolved`
- **THEN** the mobile shell can request the same explicit export contract for
  copy, share, QR, or other platform-native handoff UX
- **AND** the platform-specific clipboard or sharing behavior remains outside
  the provider and transport packages
