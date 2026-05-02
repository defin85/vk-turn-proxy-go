## ADDED Requirements

### Requirement: Platform tunnel readiness is profile-kind specific

Platform tunnel readiness SHALL be evaluated against the selected runtime
execution plan and the concrete VPN transport profile kind required by that
plan.

#### Scenario: Future profile kind lacks native adapter evidence

- **GIVEN** a host can store or edit a future VPN transport profile kind
- **AND** the packaged native adapter has not proven startup for an execution
  plan requiring that kind
- **WHEN** platform tunnel readiness is evaluated
- **THEN** readiness remains unavailable or setup-needed
- **AND** the host does not claim that a WireGuard-ready adapter proves support
  for the future kind

#### Scenario: Concrete new transport proves readiness later

- **GIVEN** a later change implements a concrete non-WireGuard VPN transport
  profile kind
- **WHEN** that change claims platform tunnel readiness
- **THEN** it includes repo-owned host/native adapter evidence for start,
  status recovery, diagnostics, and disconnect through RelayDock
- **AND** it keeps external application workflows separate from RelayDock
  native readiness claims

### Requirement: Transport profile schemas do not own platform routing policy

The system SHALL keep platform tunnel routing policy, app scope, underlay
socket protection, and VPN permission lifecycle as platform-tunnel adapter
responsibilities rather than implicit behavior hidden inside transport profile
schemas.

#### Scenario: Profile schema includes route-like material

- **GIVEN** a transport profile schema includes engine material that resembles
  route, allowed-app, DNS, MTU, or endpoint configuration
- **WHEN** the host evaluates platform tunnel startup
- **THEN** the host applies app scope, route scope, underlay socket protection,
  and Android VPN permission state from the platform tunnel contract
- **AND** it does not let profile material silently override RelayDock routing
  or app-scope policy
- **AND** conflicts fail closed with a typed prerequisite or policy error
