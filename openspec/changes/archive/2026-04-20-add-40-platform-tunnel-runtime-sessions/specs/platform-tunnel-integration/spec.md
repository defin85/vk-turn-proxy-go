## ADDED Requirements

### Requirement: Platform tunnel ready state reflects an attached runtime session

The system SHALL treat `ready=true` for a runtime-backed platform-tunnel mode
as proof that the packaged host attached the shared runtime successfully, and
SHALL surface that runtime through the ordinary session contract.

#### Scenario: Host reaches ready for a runtime-backed platform tunnel

- **GIVEN** a packaged host starts one supported platform-tunnel mode
- **AND** the host completes permission, route validation, host bring-up, and
  runtime attach successfully
- **WHEN** startup reports `ready=true`
- **THEN** the resulting runtime is visible through the ordinary typed session
  surface
- **AND** tunnel-stage detail remains available through the startup result or
  diagnostics instead of replacing the session surface

#### Scenario: Host fails before runtime-backed readiness

- **GIVEN** a packaged host starts one supported platform-tunnel mode
- **WHEN** startup fails before runtime attach reaches ready state
- **THEN** the host does not claim a ready runtime session for that attempt
- **AND** the host still reports the failing tunnel stage and cleanup outcome
  through the documented platform-tunnel result
