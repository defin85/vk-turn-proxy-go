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
- **AND** the desktop app root resolves framework localization delegates,
  supported locales, and the localized app title from the shared shell
  localization package instead of leaving framework chrome or title copy
  hardcoded in English

#### Scenario: Desktop falls back cleanly when localized host metadata is unavailable

- **GIVEN** the desktop shell renders provider or validation metadata from the
  local control plane
- **WHEN** localized display metadata for the active locale is unavailable
- **THEN** the desktop shell falls back to the base descriptor or message text
- **AND** shell-owned chrome such as actions, navigation, and empty states
  still renders in the active shell locale
- **AND** the desktop shell does not invent translations by parsing
  machine-readable ids, field keys, or violation codes

#### Scenario: Desktop exposes locale override through compact shell chrome

- **GIVEN** an operator needs to override the workstation locale on desktop
- **WHEN** they use the first localized desktop shell slice
- **THEN** the locale switch is reachable through a compact shell menu or
  equivalent top-level shell chrome entry
- **AND** the first slice does not require a dedicated settings surface only to
  change locale
