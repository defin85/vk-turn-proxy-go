## ADDED Requirements
### Requirement: Desktop GUI exposes explicit VPN transport-profile transfer

The desktop GUI SHALL expose explicit secret-bearing export and import actions
for VPN transport profiles separately from saved-profile portable transfer and
runtime handoff export.

#### Scenario: Desktop manager exports a VPN transport profile explicitly

- **GIVEN** the desktop GUI shows the VPN transport-profile manager or a setup
  surface for a configured profile
- **AND** the selected profile advertises the documented portable export action
- **WHEN** the operator chooses transport-profile export
- **THEN** the GUI presents an explicit sensitivity warning and collects the
  required transfer passphrase before export
- **AND** it can route the resulting encrypted portable transport-profile
  envelope through supported desktop file, text, or QR transfer paths as the
  shell-side presentation of the stable `file_payload`, `text_payload`, or
  `qr_payload` transfer paths in the first shipped slice
- **AND** it does not treat that action as `Export saved profile` or
  `export_handoff`

#### Scenario: Desktop import previews an encrypted transport-profile envelope

- **GIVEN** the operator provides an encrypted portable transport-profile
  envelope through a supported desktop import path
- **WHEN** the desktop shell submits that payload and passphrase for preview
- **THEN** it shows the typed host preview before confirmation
- **AND** when that preview reports an exact duplicate, the shell shows an
  explicit `already on this device` state tied to the matching local profile
  instead of a duplicate import-confirmation CTA
- **AND** when that preview reports `display_name_conflict`, the shell shows
  the host-suggested local display name as a non-blocking warning rather than
  forcing an inline rename step in the first shipped slice
- **AND** after confirmation it records only the new ordinary redacted profile
  status in desktop shell-visible state
- **AND** it does not persist the transfer passphrase as ordinary shell state

#### Scenario: Desktop QR export fails closed when encrypted payload is too large

- **GIVEN** the operator requests desktop QR export for a VPN transport profile
- **WHEN** the encrypted portable transport-profile envelope exceeds supported
  QR bounds
- **THEN** the desktop shell fails closed for QR
- **AND** it does not split the payload into multipart QR fragments in the
  first shipped slice
- **AND** it keeps file or text transfer paths available instead of truncating
  the payload

#### Scenario: Desktop imported transport profile is not auto-selected

- **GIVEN** the desktop GUI imports a compatible VPN transport profile through
  the documented encrypted transfer flow
- **WHEN** the import completes
- **THEN** the imported record appears in the VPN transport-profile manager as
  an ordinary local profile
- **AND** any startup selection or scoped-default binding still requires an
  explicit later operator action
