## ADDED Requirements
### Requirement: Shared shell core owns the supported-provider catalog

The system SHALL keep the operator-facing supported-provider catalog in
`packages/flutter_shell_core` so desktop and mobile share one application-level
provider taxonomy.

#### Scenario: Desktop and mobile read the same supported-provider catalog

- **GIVEN** both shell applications import the shared shell core
- **WHEN** they render the operator-facing provider workspace
- **THEN** they use the same supported-provider catalog from shared shell code
- **AND** that catalog contains only intentionally shipped supported providers
- **AND** host-reported descriptors are consumed as runtime overlays rather
  than as the only provider list

### Requirement: Shared presets map to supported providers only

The system SHALL keep preset definitions subordinate to the supported-provider
catalog.

#### Scenario: Shared preset targets a supported provider family

- **GIVEN** a preset definition in shared shell core
- **WHEN** the shell loads that preset
- **THEN** the preset references one provider family that already exists in the
  shared supported-provider catalog
- **AND** the preset seeds a managed provider draft or record for that family

#### Scenario: Shared shell core rejects speculative preset-only families

- **GIVEN** a provider family that is not intentionally shipped in the shared
  supported-provider catalog
- **WHEN** a shell build evaluates its shared preset catalog
- **THEN** it does not expose a preset for that unsupported family
- **AND** it does not use preset presence as proof of provider support

### Requirement: Shared managed-provider models exclude prompt-only inputs

The system SHALL keep shared managed-provider records limited to reusable
non-secret provider-owned state.

#### Scenario: Shared shell core shapes a managed-provider record

- **GIVEN** a supported provider family whose operational flow also uses
  session-scoped links, prompt-only values, or static credentials
- **WHEN** desktop or mobile shells persist a managed-provider record in shared
  shell-owned state
- **THEN** the shared model stores only reusable non-secret provider-owned
  values for that family
- **AND** prompt-only, secret, or session-scoped inputs stay in profile-local
  or custom-entry flows instead of becoming managed-provider catalog state

### Requirement: Shared shell models preserve managed-provider source mode

The system SHALL let shared shell models preserve whether a saved profile is
currently associated with a managed provider or a custom provider path.

#### Scenario: Shared shell core restores a managed-provider-backed profile

- **GIVEN** a saved profile draft or persisted profile-selection state derived
  from a managed provider record
- **WHEN** desktop or mobile shells restore that state through shared shell
  models
- **THEN** the restored model retains enough shell-local metadata to reopen in
  managed-provider mode
- **AND** the runtime control-plane payload remains a snapshot of ordinary
  `provider`, `link`, and `provider_settings` values
