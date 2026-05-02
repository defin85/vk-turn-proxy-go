# native-build-workflows Specification

## Purpose
Define the documented, repo-owned build workflows and prerequisites for native
Go and Flutter artifacts.
## Requirements
### Requirement: Repository provides target-native build entrypoints

The repository SHALL provide explicit, repo-owned build entrypoints for supported artifact targets instead of relying on ad-hoc manual commands.

#### Scenario: Operator builds Go artifacts from WSL

- **GIVEN** an operator works from the canonical WSL checkout
- **WHEN** they invoke the documented Go build entrypoint
- **THEN** the repository builds the supported Go binaries into deterministic artifact locations
- **AND** Windows-target Go binaries such as `clientd.exe` are produced without requiring a Windows Go toolchain

#### Scenario: CI runs the documented build entrypoints

- **GIVEN** a supported CI runner
- **WHEN** the repository executes its documented build workflow
- **THEN** CI calls the same repo-owned build scripts used by local workflows
- **AND** it does not depend on a separate undocumented command set

### Requirement: Windows GUI builds run from a persistent Windows-native mirror

The repository SHALL run Windows Flutter desktop builds from a persistent Windows-native mirror instead of executing the build directly from a WSL UNC path or an ad-hoc temp copy.

#### Scenario: Operator triggers Windows GUI build from WSL

- **GIVEN** the canonical source tree is in WSL and a compatible Windows-native GUI toolchain is installed
- **WHEN** the operator invokes the documented Windows GUI build entrypoint from WSL
- **THEN** the workflow synchronizes the project into a documented mirror rooted under `E:\\Projects`
- **AND** it runs the Windows-native GUI build from that mirrored path instead of from `\\\\wsl.localhost\\...`

#### Scenario: Windows GUI package stages the sidecar

- **GIVEN** a successful Windows GUI build
- **WHEN** the repository stages the packaged artifact
- **THEN** it places a compatible `clientd.exe` next to the GUI executable
- **AND** packaged startup does not depend on repo-local `go run` fallback behavior

### Requirement: Host-native build toolchains are pinned and preflight-validated

The repository SHALL detect incompatible host-native build toolchains before starting host-bound artifact builds.

#### Scenario: Windows Flutter toolchain is incompatible

- **GIVEN** the project requires a specific Flutter SDK line for `desktop/gui_shell`
- **WHEN** the operator runs the documented Windows GUI build or doctor entrypoint
- **THEN** the workflow fails before the native build starts if the installed Windows Flutter toolchain is missing or incompatible
- **AND** it reports the expected repo-managed version or bootstrap path explicitly

### Requirement: Shell build workflows expose root workspace resolution explicitly

The system SHALL treat repository-root workspace resolution as a documented
public prerequisite for Flutter shell development and build workflows once the
shell packages migrate to one repository-root workspace.

#### Scenario: Developer prepares shell dependencies from the documented workflow

- **GIVEN** a developer follows the documented workflow for desktop, mobile, or
  shared shell core work
- **WHEN** they prepare the Flutter shell packages before analysis, tests, or
  packaging
- **THEN** the workflow directs them to run repository-root `dart pub get`
- **AND** it does not present per-package `flutter pub get` as an authoritative
  replacement for the shared workspace resolution

#### Scenario: Repo-owned shell tooling does not depend on app-local resolution artifacts

- **GIVEN** repo-owned shell scripts or CI jobs run after workspace migration
- **WHEN** they verify or build Flutter shell packages
- **THEN** they use or validate the repository-root workspace resolution
- **AND** they do not depend on app-local `pubspec.lock` or app-local
  `.dart_tool/package_config.json` files for workspace members

### Requirement: Repo-owned native packaging uses canonical publish identifiers

The repository SHALL source platform package, bundle, and application
identifiers for published GUI artifacts from one dedicated repo-managed
publish-identity manifest instead of leaving placeholder or legacy identifiers
scattered across native project files and scripts.

#### Scenario: Mobile and desktop packaging read canonical publish identifiers

- **GIVEN** a repo-owned mobile or desktop packaging workflow
- **WHEN** it prepares native project metadata for a published GUI artifact
- **THEN** it reads the canonical publish-facing identifiers from the
  dedicated repo-managed publish-identity manifest
- **AND** it does not treat hard-coded placeholder values such as
  `com.defin85.mobile_gui_shell`, `com.defin85.gui_shell`, or example bundle
  identifier families as the supported published identity surface
- **AND** internal out-of-scope names such as Dart package names, import roots,
  artifact-role strings, or shell state directory stems are not misclassified
  as publish-facing identifier drift

#### Scenario: Build verification rejects mixed legacy and canonical identifiers

- **GIVEN** a native project file, script, or staging workflow still references
  a legacy placeholder identifier covered by this change
- **WHEN** the operator runs the documented build or verification workflow
- **THEN** the workflow fails before claiming a valid published package
- **AND** it reports the inconsistent identifier source explicitly

### Requirement: Repository provides a Play-compatible Android release build entrypoint

The repository SHALL provide a documented, repo-owned Android release build
entrypoint that stages a signed Google Play upload artifact from the canonical
WSL checkout instead of relying on ad hoc Android Studio release clicks or on a
debug APK workflow.

#### Scenario: Operator builds a Play-target Android release from WSL

- **GIVEN** a compatible Linux Android toolchain, canonical version assets,
  canonical publish identity, and configured release-signing inputs
- **WHEN** the operator runs the documented Android Play release entrypoint
- **THEN** the workflow stages a signed Android release artifact suitable for
  Google Play upload under a documented repository output path
- **AND** that staged upload artifact is an Android App Bundle rather than only
  a debug APK
- **AND** the workflow also stages build identity metadata and a SHA-256
  checksum with the artifact
- **AND** the metadata records the effective release target SDK and signing mode
  without writing signing secrets

#### Scenario: Release signing inputs are missing or invalid

- **GIVEN** the Android release keystore path, key alias, or passwords are
  missing or invalid
- **WHEN** the operator runs the documented Android Play release entrypoint
- **THEN** the workflow fails before staging a release artifact
- **AND** it reports the missing release-signing prerequisite explicitly
- **AND** it does not fall back to debug signing or unsigned output

### Requirement: Repository documents the operator handoff from staged Android release to Google Play

The repository SHALL document the operator-owned handoff from the staged
Android release artifact into Google Play Console instead of implying that the
repo-owned build scripts complete publication by themselves.

#### Scenario: Operator follows the documented Google Play handoff

- **GIVEN** a staged Play-target Android release artifact from the documented
  repo-owned workflow
- **WHEN** the operator follows the documented publication handoff
- **THEN** the docs enumerate the required manual Google Play surfaces,
  including Play App Signing enrollment, release-track upload, store
  listing/contact details, app-content declarations, and manifest-derived
  policy surfaces such as Data safety, privacy/support contact, content rating,
  target audience, VPN service, `QUERY_ALL_PACKAGES`, camera, and foreground
  service use when present
- **AND** the docs keep those steps explicit as operator-owned work rather than
  pretending that the repository auto-publishes to Google Play

### Requirement: Play-target Android release preflight validates current submission prerequisites

The repository SHALL fail closed when the Android release configuration no
longer satisfies the repo-managed Google Play submission floor. The floor SHALL
be an explicit documented numeric Android API level and SHALL be checked against
the effective release `targetSdkVersion` after Gradle/Flutter resolution.

#### Scenario: Android target floor is below the supported Play release minimum

- **GIVEN** the current Android release configuration or toolchain targets
  below the repo-managed Google Play submission floor
- **WHEN** the operator runs the documented Android Play release entrypoint
- **THEN** the workflow fails before staging the release artifact
- **AND** it reports which Android release prerequisite is insufficient,
  including the documented floor and the resolved effective release target SDK,
  instead of waiting for Play Console upload rejection

