## ADDED Requirements

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
