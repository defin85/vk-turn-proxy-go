## ADDED Requirements
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
