## ADDED Requirements
### Requirement: Android proxy-only mode is an explicit non-system runtime

The system SHALL treat the first Android proxy-only path as an explicit
non-system runtime mode rather than as a hidden variant of
`android_vpn_service`.

#### Scenario: Operator starts Android proxy-only mode

- **GIVEN** a packaged Android build that supports the documented proxy-only
  mode
- **WHEN** the operator enables that mode
- **THEN** the repository presents it as a non-system proxy workflow
- **AND** it does not imply Android system-tunnel semantics for that mode

### Requirement: Android proxy-only mode exposes typed local proxy endpoints

The system SHALL surface the first Android proxy-only mode through typed local
proxy endpoint metadata instead of generic free-form operator instructions.

#### Scenario: Proxy-only runtime reaches ready state

- **GIVEN** a packaged Android build whose embedded host starts the documented
  proxy-only mode successfully
- **WHEN** the mode reaches ready state
- **THEN** the host reports typed local proxy endpoint metadata for that mode
- **AND** the mobile shell can render those endpoints without guessing them
  from logs or ad hoc text

### Requirement: Android proxy-only mode is app-opt-in and fail-closed on unsupported scope

The system SHALL require explicit app or operator opt-in for proxy-only mode
instead of implying transparent traffic capture.

#### Scenario: Target app cannot use the documented proxy path

- **GIVEN** an Android app or operator workflow that cannot apply the
  documented local proxy endpoint
- **WHEN** the operator inspects or attempts proxy-only mode
- **THEN** the repository keeps that mode explicit as unavailable or
  incomplete for that target
- **AND** it does not silently widen the mode into system-wide capture
