## ADDED Requirements

### Requirement: Desktop packaged shell uses canonical RelayDock application identifiers

The system SHALL package the desktop shell with canonical RelayDock
application identifiers on platforms that expose bundle or application
identifiers instead of placeholder `gui_shell` identifier families.

#### Scenario: Linux desktop runtime uses the canonical application identifier

- **GIVEN** a packaged Linux desktop build
- **WHEN** the app launches and integrates with the host desktop environment
- **THEN** the GTK application identifier and related desktop-integration
  metadata use the canonical RelayDock desktop identifier
- **AND** the published Linux build does not keep `com.defin85.gui_shell` as
  its supported application identifier

#### Scenario: macOS bundle uses the canonical desktop bundle identifier

- **GIVEN** the repo-owned macOS desktop build metadata
- **WHEN** the Runner app bundle is packaged or signed
- **THEN** the main bundle and related test targets derive from the canonical
  RelayDock desktop bundle identifier
- **AND** the published desktop app does not keep example or placeholder
  bundle identifiers such as `com.example.guiShell`
