## ADDED Requirements
### Requirement: Desktop GUI renders provider-defined settings generically

The system SHALL let the desktop GUI render provider-defined settings from
host-reported descriptor metadata rather than from provider-name-specific form
branches.

#### Scenario: Desktop shows descriptor-defined settings without provider branching

- **GIVEN** a provider descriptor with `provider_settings_schema`
- **WHEN** the operator opens the provider entry surface
- **THEN** the desktop GUI renders supported controls from the schema
  annotations and `x-vkturn-*` hints
- **AND** it keeps provider settings visually separate from runtime defaults
- **AND** it does not add desktop-only provider-specific form code for that
  provider

### Requirement: Desktop GUI persists only allowed provider settings locally

The system SHALL keep prompt-only provider values out of ordinary desktop shell
state.

#### Scenario: Desktop persists a draft containing profile-retained and prompt-only fields

- **GIVEN** a draft with both profile-retained and prompt-only provider settings
- **WHEN** the desktop GUI saves local shell state or a saved profile
- **THEN** it keeps only the descriptor-allowed profile-retained non-secret
  settings in persisted state
- **AND** it clears link-like, write-only, or `ephemeral` provider setting
  values from plaintext local state
