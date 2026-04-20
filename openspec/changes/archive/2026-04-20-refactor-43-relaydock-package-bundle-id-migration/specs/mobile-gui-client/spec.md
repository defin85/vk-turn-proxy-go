## ADDED Requirements

### Requirement: Mobile packaged shell uses the canonical RelayDock mobile identifier

The system SHALL package the production mobile shell under the canonical
RelayDock mobile package and bundle identifier family instead of legacy
`mobile_gui_shell` placeholder identities.

#### Scenario: Production Android package uses the canonical mobile application identifier

- **GIVEN** the repo-owned Android mobile packaging workflow
- **WHEN** the production mobile package is assembled
- **THEN** the Android `applicationId`, namespace, manifest-owned components,
  and package-oriented repo automation use the canonical RelayDock mobile
  identifier
- **AND** repo docs do not present `com.defin85.mobile_gui_shell` as the
  supported published package identity

#### Scenario: iOS mobile bundle uses the canonical mobile bundle identifier

- **GIVEN** the repo-owned iOS mobile build metadata
- **WHEN** the Runner bundle is packaged or signed
- **THEN** the main app and related test targets derive from the canonical
  RelayDock mobile bundle identifier
- **AND** the published mobile app does not keep placeholder bundle
  identifiers from the `mobileGuiShell` family

#### Scenario: Mobile publish-identity cutover does not hide state-migration limits

- **GIVEN** the supported mobile package or bundle identifier changes to the
  canonical RelayDock identity
- **WHEN** the operator follows the documented migration or install workflow
- **THEN** the workflow states explicitly whether shell-owned preferences and
  secure-storage contents are preserved or must be re-entered
- **AND** it does not present the identity cutover as a seamless in-place
  update unless a reviewed migration path is part of the supported workflow
