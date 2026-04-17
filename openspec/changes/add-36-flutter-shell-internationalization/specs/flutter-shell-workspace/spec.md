## ADDED Requirements

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
