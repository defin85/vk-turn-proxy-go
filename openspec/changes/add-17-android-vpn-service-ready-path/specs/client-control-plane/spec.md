## ADDED Requirements
### Requirement: Client control plane accepts Android tunnel startup policy through the canonical contract

The system SHALL carry packaged Android `android_vpn_service` startup inputs
through the canonical versioned client-control-plane contract instead of
requiring Flutter shells to infer or apply Android package policy locally.

#### Scenario: Shell starts Android system tunnel with an explicit app-scope policy

- **GIVEN** a packaged Android host that advertises the documented
  `android_vpn_service` mode
- **WHEN** the mobile shell starts that mode with one supported
  `application_routing_policy` and any required selected package set
- **THEN** the startup request flows through the canonical control-plane
  contract
- **AND** the packaged host validates and applies that app-scope policy inside
  the Android host boundary
- **AND** the shell does not reinterpret or widen the package policy locally

#### Scenario: Shell requests an invalid Android app-scope policy

- **GIVEN** a packaged Android host starting `android_vpn_service`
- **WHEN** the shell sends a mixed, incomplete, or otherwise invalid
  `application_routing_policy` request through the control plane
- **THEN** the host returns a typed startup failure through that same contract
- **AND** the shell does not guess a fallback package policy outside the host

### Requirement: Android permission acquisition stays under the canonical control plane

The system SHALL surface Android VPN permission acquisition through the same
versioned client-control-plane startup contract instead of introducing a second
shell-visible Android tunnel protocol.

#### Scenario: Android startup requires VPN permission before host bring-up can continue

- **GIVEN** a packaged Android host starting the documented
  `android_vpn_service` path
- **WHEN** the host reaches the Android permission prerequisite before it can
  continue with route validation or runtime attach
- **THEN** the host reports that prerequisite through the canonical
  client-control-plane startup semantics
- **AND** the shell can drive the documented Android permission workflow
  without switching to a parallel shell-visible tunnel API
- **AND** any package-internal bridge to the Kotlin `VpnService` adapter
  remains a host-internal implementation detail
