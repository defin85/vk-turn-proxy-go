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
