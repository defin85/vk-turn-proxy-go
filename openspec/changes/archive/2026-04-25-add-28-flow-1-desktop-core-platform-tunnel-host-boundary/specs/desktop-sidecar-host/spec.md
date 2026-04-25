## ADDED Requirements
### Requirement: Packaged desktop host coordinates native tunnel startup behind one host boundary

The system SHALL let the packaged desktop host coordinate documented
system-tunnel startup through its native adapter boundary instead of routing
privileged tunnel work through the Flutter shell.

#### Scenario: Packaged desktop host starts one desktop mode through its native adapter

- **GIVEN** a production desktop package with the documented bundled host and
  one supported native desktop adapter
- **WHEN** the operator starts the packaged desktop system-tunnel workflow
- **THEN** the packaged desktop host reaches that native adapter through the
  documented host boundary
- **AND** the app does not require shell-local orchestration or an undefined
  second helper API to reach the typed startup result
