## ADDED Requirements
### Requirement: Desktop packages can stage embedded host backend artifacts with sidecar fallback

The repository SHALL treat embedded desktop host artifacts as explicit package
outputs when a desktop target enables embedded mode. Packaging SHALL keep a
compatible sidecar `clientd` fallback until a later reviewed change removes
that fallback for a specific target.

#### Scenario: Package stages embedded host artifacts

- **GIVEN** a desktop target enables the embedded host backend
- **WHEN** the repository runs the documented package build workflow
- **THEN** the package stages the required bridge, native library, plugin, or
  equivalent embedded host artifacts
- **AND** package metadata records the embedded host build identity and
  compatible control-plane contract version

#### Scenario: Package verification rejects embedded/sidecar mismatch

- **GIVEN** a desktop package stages embedded host artifacts and sidecar
  fallback artifacts
- **WHEN** package verification inspects the staged package
- **THEN** verification fails if either backend advertises an incompatible
  control-plane version, missing required capabilities, or mismatched product
  build identity
- **AND** the failure identifies whether the embedded backend, sidecar backend,
  or shared staging metadata is inconsistent

#### Scenario: Operator can force sidecar mode

- **GIVEN** a packaged desktop build contains both embedded and sidecar host
  backends
- **WHEN** the operator or support runbook disables embedded mode for
  diagnostics or rollback
- **THEN** the shell uses the documented sidecar backend
- **AND** diagnostics record that sidecar mode was selected intentionally
