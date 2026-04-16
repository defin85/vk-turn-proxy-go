## ADDED Requirements

### Requirement: Mobile GUI shell supports explicit portable profile transfer with QR and platform-native share/import paths

The system SHALL let the mobile shell explicitly export and import saved
profiles through the shared portable-profile envelope using mobile-native share,
file, and QR workflows.

#### Scenario: Mobile exports a saved profile through QR or platform-native transfer

- **GIVEN** a saved profile in the mobile shell
- **WHEN** the operator chooses profile export
- **THEN** the mobile shell can render the shared portable-profile envelope as
  QR and expose platform-native share or file actions from that same envelope
- **AND** if the payload does not fit the supported QR bounds, the shell fails
  closed for QR and keeps non-QR transfer available instead of emitting a
  partial QR payload

#### Scenario: Mobile imports a portable profile from QR scan or supported file/share ingress

- **GIVEN** the operator scans a supported portable-profile QR or opens a valid
  portable-profile payload through a supported mobile file/share ingress path
- **WHEN** the mobile shell validates that envelope
- **THEN** it creates a local imported profile in the Profiles workflow
- **AND** it restores managed-provider mode when the envelope includes the
  required managed-provider snapshot
- **AND** it does not auto-connect, auto-resolve, auto-launch browser
  continuation, or silently overwrite an existing local profile

#### Scenario: Mobile keeps secret-bearing profile transfer explicit

- **GIVEN** a portable profile export or import whose envelope is marked as
  secret-bearing
- **WHEN** the mobile shell presents that transfer action
- **THEN** it surfaces that sensitivity to the operator before completing the
  transfer
- **AND** it does not treat that envelope as ordinary persisted app state
