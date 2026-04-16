## ADDED Requirements

### Requirement: Shared shell core defines a versioned portable-profile envelope

The system SHALL define one shared, versioned portable-profile envelope in
`packages/flutter_shell_core` for explicit shell-to-shell profile transfer.

#### Scenario: Shared shell core serializes one saved profile for transfer

- **GIVEN** a saved desktop or mobile shell profile plus its shell-local source
  metadata
- **WHEN** the shell requests portable profile export
- **THEN** shared shell core produces one versioned envelope that contains the
  profile snapshot and any managed-provider snapshot needed to reopen that
  profile in the same managed/custom source mode on another shell
- **AND** the envelope does not reuse the ordinary persisted shell-state file
  shape as an implicit transfer contract

#### Scenario: Shared shell core does not trust source-local ids during import

- **GIVEN** a portable-profile envelope whose profile or managed-provider ids
  collide with local ids on the destination shell
- **WHEN** the shell imports that envelope
- **THEN** the shared import model requires fresh local ids or an explicit
  operator-reviewed replacement path
- **AND** it does not silently overwrite unrelated local shell records by
  trusting source-local ids

### Requirement: Shared portable profile transfer stays distinct from runtime handoff export and ordinary persistence

The system SHALL keep portable profile transfer separate from ordinary redacted
shell persistence and from runtime handoff export.

#### Scenario: Shared envelope marks secret-bearing transfer state

- **GIVEN** a saved profile whose portable transfer payload includes invite
  links, handoff links, or other secret-bearing input needed to reconstruct the
  profile on another shell
- **WHEN** shared shell core produces the portable-profile envelope
- **THEN** the envelope reports that it is secret-bearing so platform UI can
  warn the operator before sharing, saving, or rendering QR
- **AND** existing desktop/mobile ordinary persisted shell state remains
  governed by the current redacted persistence rules

#### Scenario: Runtime handoff export does not masquerade as profile export

- **GIVEN** a shell that supports both portable profile transfer and explicit
  runtime handoff export
- **WHEN** the operator requests one of those actions
- **THEN** the shared shell model keeps the portable-profile envelope distinct
  from the typed `export_handoff` runtime artifact contract
- **AND** neither path silently substitutes for the other
