## ADDED Requirements

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
