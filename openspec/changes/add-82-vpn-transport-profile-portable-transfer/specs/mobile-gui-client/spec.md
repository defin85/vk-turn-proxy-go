## ADDED Requirements
### Requirement: Mobile GUI exposes explicit VPN transport-profile transfer

The mobile GUI SHALL expose explicit secret-bearing export and import actions
for VPN transport profiles separately from saved-profile portable transfer.

#### Scenario: Mobile manager exports a VPN transport profile explicitly

- **GIVEN** the mobile shell shows the VPN transport-profile manager or a
  setup surface for a configured profile
- **AND** the selected profile advertises the documented portable export action
- **WHEN** the operator chooses transport-profile export
- **THEN** the shell presents an explicit sensitivity warning and collects the
  required transfer passphrase before export
- **AND** it routes only the encrypted portable transport-profile envelope
  through supported mobile share, file, text, or QR surfaces as the shell-side
  presentation of the stable `file_payload`, `text_payload`, or `qr_payload`
  transfer paths in the first shipped slice
- **AND** it does not label that action as `Export saved profile`

#### Scenario: Mobile import previews an encrypted transport-profile envelope

- **GIVEN** the operator opens an encrypted portable transport-profile payload
  through a supported mobile ingress path such as file, share, pasted text, or
  scanned QR
- **WHEN** the mobile shell submits that payload and passphrase for preview
- **THEN** it shows the typed preview returned by the host before import
- **AND** when that preview reports an exact duplicate, the shell shows an
  explicit `already on this device` state tied to the matching local profile
  instead of a duplicate import-confirmation CTA
- **AND** when that preview reports `display_name_conflict`, the shell shows
  the host-suggested local display name as a non-blocking warning rather than
  forcing an inline rename step in the first shipped slice
  confirmation
- **AND** it does not persist the imported secret-bearing profile material as
  ordinary mobile shell state

#### Scenario: Mobile QR export fails closed when encrypted payload is too large

- **GIVEN** the operator requests mobile QR export for a VPN transport profile
- **WHEN** the encrypted portable transport-profile envelope exceeds supported
  QR bounds
- **THEN** the mobile shell fails closed for QR
- **AND** it does not split the payload into multipart QR fragments in the
  first shipped slice
- **AND** it keeps non-QR transfer paths available instead of truncating the
  secret-bearing payload

#### Scenario: Imported transport profile stays separate from saved profiles

- **GIVEN** the mobile shell imports a VPN transport profile successfully
- **WHEN** the operator returns to the `Profiles` workspace
- **THEN** the imported transport profile remains owned by the VPN
  transport-profile manager and Routing/Home setup surfaces
- **AND** saved-profile portable transfer remains a separate workflow for shell
  profile records
