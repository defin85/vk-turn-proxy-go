## ADDED Requirements

### Requirement: Store-target Android packages stay aligned with the production mobile-host slice

The system SHALL keep Google Play-target Android packages aligned with the
packaged-host production mobile slice rather than with debug-only local-device
conveniences.

#### Scenario: Store-target Android package boots without debug-only local assets

- **GIVEN** a Google Play-target Android package built through the documented
  release workflow
- **WHEN** the operator installs and launches that package
- **THEN** the mobile GUI boots through the packaged mobile host bridge
- **AND** it does not require a development bridge override or bundled
  repo-local WireGuard development profile assets to start its supported
  production slice

#### Scenario: Store-target Android package excludes workstation-local seeded assets

- **GIVEN** repo-local mobile debug assets or workstation-local seeded files
  exist while the Android release package is assembled for Google Play
- **WHEN** the release packaging workflow stages the store-target artifact
- **THEN** those local development assets are excluded from the packaged mobile
  artifact
- **AND** the published package contents do not depend on one workstation's
  local state
