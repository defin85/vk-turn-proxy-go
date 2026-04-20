# flutter-shell-workspace Specification

## Purpose
Define the repository-owned Flutter workspace contract for the desktop shell,
mobile shell, and shared shell core.
## Requirements
### Requirement: Shell packages resolve through one repo-owned Flutter workspace

The system SHALL resolve the desktop shell, mobile shell, and shared shell core
through one repository-root Flutter/Dart workspace.

#### Scenario: Repository-root workspace resolves the shell packages

- **GIVEN** the repository shell packages
- **WHEN** shell dependencies are resolved
- **THEN** the repository-root workspace resolves `desktop/gui_shell`,
  `mobile/gui_shell`, and `packages/flutter_shell_core`
- **AND** the shared shell core does not require manual copy steps between app
  packages
- **AND** the root workspace lists those members explicitly instead of relying
  on glob-based package discovery

#### Scenario: Workspace resolution uses root-owned artifacts

- **GIVEN** the repository shell packages participate in one repository-root
  workspace
- **WHEN** the canonical workspace resolution step runs
- **THEN** one root `pubspec.lock` and one root `.dart_tool/package_config.json`
  represent the shared workspace resolution
- **AND** repo-owned shell tooling does not depend on app-local copies of those
  resolution artifacts for workspace members

#### Scenario: App-local validation stays valid after workspace migration

- **GIVEN** the shell packages participate in a repository-root workspace
- **WHEN** desktop or mobile shell validation runs from the app package
- **THEN** `flutter analyze` and `flutter test` still run from the app-local
  package directories
- **AND** those commands validate the same shared-resolution topology created by
  the workspace

#### Scenario: Root workspace resolution is part of the public shell workflow

- **GIVEN** a developer follows the documented shell workflow in this repository
- **WHEN** they prepare dependencies for desktop, mobile, or shared shell core
  work
- **THEN** the documented workflow starts with repository-root `dart pub get`
- **AND** app-local verification and packaging commands are presented as steps
  that run after that shared workspace resolution

### Requirement: Desktop and mobile remain separate shell applications

The system SHALL keep the desktop shell and mobile shell as separate Flutter
app packages even after the shared workspace and shared shell core are added.

#### Scenario: Desktop app keeps desktop-specific runtime ownership

- **GIVEN** the desktop GUI shell
- **WHEN** it launches, discovers, or supervises a compatible local host and
  persists desktop-local shell state
- **THEN** that behavior stays in desktop-specific app code
- **AND** the workspace does not require desktop runtime ownership to move into
  a merged app package

#### Scenario: Mobile app keeps mobile-specific runtime ownership

- **GIVEN** the mobile GUI shell
- **WHEN** it resolves a native host bridge, uses secure storage, or reacts to
  lifecycle and browser handoff events
- **THEN** that behavior stays in mobile-specific app code
- **AND** the workspace does not require mobile runtime ownership to move into
  a merged app package

### Requirement: Shared shell core remains platform-neutral

The system SHALL keep the shared shell core package limited to
platform-neutral shell code.

#### Scenario: Shared shell core owns common control-plane-facing modules

- **GIVEN** platform-neutral shell modules such as typed control-plane models,
  control-plane HTTP client logic, profile draft shaping, or build identity
  helpers
- **WHEN** both desktop and mobile shells need that behavior
- **THEN** that logic lives in `packages/flutter_shell_core`
- **AND** desktop and mobile import the same shared implementation

#### Scenario: App-specific artifact identity defaults stay app-local

- **GIVEN** desktop and mobile shells expose different artifact role or target
  defaults at runtime
- **WHEN** build identity helpers move into the shared shell core
- **THEN** only platform-neutral build identity shaping moves into the shared
  package
- **AND** desktop-local and mobile-local wrappers keep their app-specific role
  and target defaults

#### Scenario: Shared shell core does not take ownership of platform plugins

- **GIVEN** a shell feature that needs secure storage, URL launching, native
  bridge code, filesystem placement, or local sidecar process control
- **WHEN** the repository assigns ownership for that feature
- **THEN** the desktop or mobile app package keeps that adapter locally
- **AND** `packages/flutter_shell_core` remains a regular Flutter package
  without direct ownership of platform-specific plugin integrations

### Requirement: Shared shell core owns the supported-provider catalog

The system SHALL keep the operator-facing supported-provider catalog in
`packages/flutter_shell_core` so desktop and mobile share one
application-level provider taxonomy.

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

### Requirement: Shared shell core defines a versioned portable-profile envelope

The system SHALL define one shared, versioned portable-profile envelope in
`packages/flutter_shell_core` for explicit shell-to-shell profile transfer.

#### Scenario: Shared shell core serializes one saved profile for transfer

- **GIVEN** a saved desktop or mobile shell profile plus its shell-local source
  metadata
- **WHEN** the shell requests portable profile export
- **THEN** shared shell core produces one versioned envelope that contains the
  profile snapshot and any managed-provider snapshot needed to reopen that
  profile in the same managed/custom source mode on another shell
- **AND** the envelope does not reuse the ordinary persisted shell-state file
  shape as an implicit transfer contract

#### Scenario: Shared shell core keeps templates out of the portable profile dependency graph

- **GIVEN** a saved profile whose reusable provider was originally authored
  from a shipped or user template
- **WHEN** shared shell core serializes that profile for portable transfer
- **THEN** the envelope carries only the saved profile snapshot and any
  managed-provider snapshot required to preserve its provider binding
- **AND** it does not require provider-template entries to exist on the
  destination shell before import can succeed

#### Scenario: Shared shell core does not trust source-local ids during import

- **GIVEN** a portable-profile envelope whose profile or managed-provider ids
  collide with local ids on the destination shell
- **WHEN** the shell imports that envelope
- **THEN** the shared import model allocates fresh local ids for the imported
  profile and any imported managed-provider snapshot
- **AND** it does not silently overwrite unrelated local shell records by
  trusting source-local ids

#### Scenario: Shared shell core rejects unsupported envelope versions

- **GIVEN** a portable-profile payload whose declared envelope version is
  unknown to the current shell build
- **WHEN** the shell validates that payload for import
- **THEN** shared shell core rejects the payload explicitly
- **AND** it does not partially import the profile under guessed compatibility
  rules

### Requirement: Shared portable profile transfer stays distinct from runtime handoff export and ordinary persistence

The system SHALL keep portable profile transfer separate from ordinary redacted
shell persistence and from runtime handoff export.

#### Scenario: Shared envelope marks secret-bearing transfer state

- **GIVEN** a saved profile whose portable transfer payload includes invite
  links, handoff links, or other secret-bearing input needed to reconstruct the
  profile on another shell
- **WHEN** shared shell core produces the portable-profile envelope
- **THEN** the envelope reports that it is secret-bearing so platform UI can
  warn the operator before sharing, saving, rendering QR, or confirming import
- **AND** existing desktop/mobile ordinary persisted shell state remains
  governed by the current redacted persistence rules

#### Scenario: Runtime handoff export does not masquerade as profile export

- **GIVEN** a shell that supports both portable profile transfer and explicit
  runtime handoff export
- **WHEN** the operator requests one of those actions
- **THEN** the shared shell model keeps the portable-profile envelope distinct
  from the typed `export_handoff` runtime artifact contract
- **AND** neither path silently substitutes for the other

### Requirement: Flutter workspace owns one shared shell localization package

The system SHALL keep shell-owned localization resources in one repo-owned
shared Flutter package so desktop, mobile, and `flutter_shell_core` reuse one
typed translation API.

#### Scenario: Desktop, mobile, and shared shell core use one translation boundary

- **GIVEN** the repository Flutter workspace contains desktop, mobile, and
  shared shell packages
- **WHEN** shell-owned operator copy is resolved for rendering
- **THEN** desktop, mobile, and `flutter_shell_core` import one repo-owned
  shared localization package
- **AND** shared widgets do not require app-specific callback chains just to
  read common translated strings
- **AND** platform-specific locale persistence adapters remain in app-local
  code instead of moving into the shared package

#### Scenario: Localization generation stays compatible with the shared workspace

- **GIVEN** the shell packages resolve through the repository-root workspace
- **WHEN** the repo-owned localization generation step runs
- **THEN** generated localization source lands in repository-owned package
  source paths
- **AND** ordinary `flutter analyze` and `flutter test` runs from app package
  directories do not depend on synthetic package imports or app-local copies of
  shared translations

#### Scenario: First locale slice keeps additive scaffold for later locales

- **GIVEN** the first shared shell localization rollout verifies `en` and `ru`
- **WHEN** the repository later adds another shell locale
- **THEN** the shared localization package source layout and generation config
  accept that locale without moving shell-owned copy back into app-local
  packages
- **AND** app packages do not need separate translation copies to prepare for
  that later locale

