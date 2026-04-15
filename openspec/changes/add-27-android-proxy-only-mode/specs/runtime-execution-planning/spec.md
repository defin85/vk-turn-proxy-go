## ADDED Requirements
### Requirement: Android proxy-only mode uses its own execution tuple

The system SHALL give Android proxy-only mode its own documented runtime
execution tuple instead of reusing the `android_vpn_service` tuple.

#### Scenario: Proxy-only mode is added to runtime planning

- **GIVEN** a future Android runtime mode that exposes local proxy endpoints
  without using `android_vpn_service`
- **WHEN** the repository adds that mode to runtime-execution planning
- **THEN** it appears as its own documented execution tuple such as a
  proxy-only Android host adapter path
- **AND** it does not reuse the `android_vpn_service` host-adapter semantics by
  implication
