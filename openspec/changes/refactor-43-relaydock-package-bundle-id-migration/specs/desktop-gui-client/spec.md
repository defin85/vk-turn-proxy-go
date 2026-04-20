## ADDED Requirements

### Requirement: Desktop packaged shell uses canonical RelayDock desktop packaging identity

The system SHALL package the desktop shell with canonical RelayDock desktop
packaging identity on platforms that expose bundle or application identifiers
or bundled app output names instead of placeholder `gui_shell` identifier
families.

#### Scenario: Linux desktop runtime uses the canonical application identifier

- **GIVEN** a packaged Linux desktop build
- **WHEN** the app launches and integrates with the host desktop environment
- **THEN** the GTK application identifier and related desktop-integration
  metadata use the canonical RelayDock desktop identifier
- **AND** the published Linux build does not keep `com.defin85.gui_shell` or
  the legacy `gui_shell` desktop shell stem as its supported packaged desktop
  identity

#### Scenario: macOS bundle uses the canonical desktop bundle identifier

- **GIVEN** the repo-owned macOS desktop build metadata and bundled app output
- **WHEN** the Runner app bundle is packaged or signed
- **THEN** the main bundle, related test targets, and bundled app output
  derive from the canonical RelayDock desktop identity
- **AND** the published desktop app does not keep example or placeholder
  bundle identifiers such as `com.example.guiShell` or legacy shell output
  names such as `gui_shell.app`
