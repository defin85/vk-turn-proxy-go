## ADDED Requirements
### Requirement: Mobile GUI renders provider-defined settings from descriptors

The system SHALL let the mobile GUI consume the same provider-defined settings
contract as desktop without reintroducing provider-specific UI logic.

#### Scenario: Mobile shows descriptor-defined settings from the host

- **GIVEN** a mobile GUI connected to a compatible host
- **AND** the selected provider descriptor includes `provider_settings_schema`
- **WHEN** the operator opens the provider entry surface
- **THEN** the mobile GUI renders the supported provider settings from the
  descriptor metadata
- **AND** it keeps those settings separate from runtime defaults and mobile-only
  handoff actions

### Requirement: Mobile GUI does not persist prompt-only provider settings

The system SHALL keep prompt-only provider values out of ordinary mobile shell
state.

#### Scenario: Mobile persists local shell state after provider settings entry

- **GIVEN** a draft containing profile-retained settings plus `writeOnly` or
  `ephemeral` provider settings
- **WHEN** the mobile GUI persists local shell state
- **THEN** it retains only the descriptor-allowed reusable non-secret settings
- **AND** it clears prompt-only provider values from preferences, secure
  storage, and other ordinary restored state
