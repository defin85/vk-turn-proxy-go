## ADDED Requirements

### Requirement: Desktop GUI shell supports explicit portable profile transfer

The system SHALL let the desktop shell explicitly export and import saved
profiles through the shared portable-profile envelope instead of relying on
ordinary shell-state files or runtime handoff export.

#### Scenario: Desktop exports a saved profile through file/text and QR-ready transfer

- **GIVEN** a saved profile in the desktop shell
- **WHEN** the operator chooses profile export
- **THEN** the desktop shell can produce the shared portable-profile envelope
  for supported file or text transfer paths
- **AND** it can present an operator-visible QR transfer surface from that same
  envelope when the payload fits the supported QR bounds
- **AND** if the payload does not fit those QR bounds, the shell fails closed
  for QR and keeps non-QR export available instead of truncating the payload

#### Scenario: Desktop imports a portable profile into the Profiles workspace

- **GIVEN** the operator provides a valid portable-profile envelope through a
  supported desktop import path such as file import or pasted envelope text
- **WHEN** the desktop shell accepts that import
- **THEN** it first shows a preview and explicit confirmation surface for the
  imported profile
- **AND** after operator confirmation it creates a local imported profile in
  the Profiles workspace
- **AND** it restores managed-provider mode when the envelope includes the
  required managed-provider snapshot
- **AND** it allocates fresh local ids for the imported profile and imported
  managed-provider snapshot
- **AND** it does not auto-resolve, auto-start runtime, or silently overwrite
  an existing local profile

#### Scenario: Desktop keeps secret-bearing profile transfer explicit

- **GIVEN** a portable profile export or import whose envelope is marked as
  secret-bearing
- **WHEN** the desktop shell presents that transfer action
- **THEN** it surfaces that sensitivity to the operator before completing the
  transfer
- **AND** it does not generate or persist that portable envelope as part of
  ordinary background shell state
