## ADDED Requirements

### Requirement: Play release follow-up distinguishes published-device launch evidence

The repository SHALL keep Play-distributed Android launch evidence distinct from
local build and local install evidence when investigating a post-publication
startup failure.

#### Scenario: Operator compares Play-installed package with staged release metadata

- **GIVEN** a Play-distributed RelayDock package fails to launch on a physical
  smartphone
- **AND** the repository has staged release metadata for the candidate Android
  Play artifact
- **WHEN** the operator compares the installed package with the staged release
  metadata
- **THEN** the comparison records package id, versionName/versionCode, signer,
  install source, ABI/native-library surface, and build identity where
  available
- **AND** it reports any mismatch between the Play-installed package and the
  staged repository artifact before claiming that a repo code change is the
  root cause
- **AND** local debug or sideloaded release evidence is labeled as secondary
  comparison evidence unless it is the same distribution path that failed

### Requirement: Play release workflow validates local delivered APK splits before staging

The repository SHALL include a repo-owned local delivery verifier for Android
Play release App Bundles that uses a pinned official `bundletool-all` jar to
build device-targeted APK splits and inspect the delivered package surface
before a release artifact is staged for handoff.

#### Scenario: Release AAB loses embedded-host bridge methods after shrink

- **GIVEN** the Android Play release workflow produced a signed Android App
  Bundle
- **WHEN** the local delivery verifier builds APK splits from that App Bundle
  with the pinned `bundletool-all` jar
- **THEN** it verifies the delivered split set contains the required embedded
  host native libraries for the selected device ABI
- **AND** it rejects debug-only or one-off proof assets in the delivered APKs
- **AND** it fails before staging the release artifact if the delivered dex
  does not retain the Android embedded-host JNI bridge callback method names
  required by the native platform tunnel bridge
