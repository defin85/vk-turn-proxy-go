## ADDED Requirements

### Requirement: Desktop GUI shell localizes shell-owned operator copy

The system SHALL localize desktop shell-owned operator copy and select the
active locale from device defaults plus an explicit shell-local operator
override.

#### Scenario: Desktop boot picks persisted override or device locale

- **GIVEN** the desktop GUI shell launches on a workstation with a preferred
  locale
- **WHEN** no shell-local locale override has been saved
- **THEN** the app uses the supported device locale or the documented default
  locale when the device locale is unsupported
- **AND** when a shell-local locale override exists the app restores that
  override on launch
- **AND** locale preference remains desktop-shell-local instead of becoming a
  host-global runtime setting

#### Scenario: Desktop falls back cleanly when localized host metadata is unavailable

- **GIVEN** the desktop shell renders provider or validation metadata from the
  local control plane
- **WHEN** localized display metadata for the active locale is unavailable
- **THEN** the desktop shell falls back to the base descriptor or message text
- **AND** shell-owned chrome such as actions, navigation, and empty states
  still renders in the active shell locale
- **AND** the desktop shell does not invent translations by parsing
  machine-readable ids, field keys, or violation codes
