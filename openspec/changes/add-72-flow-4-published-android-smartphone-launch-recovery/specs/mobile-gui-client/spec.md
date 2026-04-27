## ADDED Requirements

### Requirement: Published Android install launch failures are diagnosed from device evidence

The system SHALL treat a launch failure from a Play-distributed Android install
as a physical-device acceptance failure until the affected smartphone produces
enough evidence to identify the failing startup layer.

#### Scenario: Operator investigates a Play-installed app that does not launch

- **GIVEN** RelayDock has been installed on the operator smartphone from a
  Google Play testing or publication track
- **AND** the app does not reach a usable first frame when launched
- **WHEN** the operator investigates the failure
- **THEN** the investigation captures the installed package identity,
  versionName/versionCode, signer fingerprint, install source, Android version,
  CPU ABI, and timestamped launch result from that smartphone
- **AND** it captures scoped device logs for Java exceptions, native crashes,
  linker errors, Flutter engine startup failures, and Android package-manager
  launch or install errors
- **AND** it does not substitute a local debug or `flutter run` launch for the
  Play-installed failure evidence

### Requirement: Published Android launch recovery proves the same-device result

The system SHALL close a Play-distributed Android startup failure only after the
confirmed fix or operator action is verified against the affected smartphone.

#### Scenario: Root cause is fixed and the published install launches

- **GIVEN** the investigation identified the startup root cause from the
  affected smartphone evidence
- **WHEN** the repository or operator applies the required fix and installs the
  corrected package through the same distribution path or a documented
  equivalent release artifact
- **THEN** RelayDock reaches a usable first frame on the same smartphone
- **AND** the verification records screenshot, driver, logcat, or equivalent
  device evidence
- **AND** the investigation documents whether the final proof came from Play
  delivery, a sideloaded release artifact, or another explicitly named path
