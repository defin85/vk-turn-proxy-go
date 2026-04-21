## ADDED Requirements
### Requirement: Platform tunnel startup validates address-family coverage before readiness

The system SHALL validate the traffic address-family coverage required by the
active underlay and requested packaged platform-tunnel semantics before
claiming `ready=true`.

#### Scenario: Dual-stack underlay fails closed when IPv6 route preparation is missing

- **GIVEN** a packaged platform-tunnel mode whose host can observe active IPv6
  underlay connectivity
- **WHEN** startup cannot prepare or preserve the documented IPv6 route,
  exclusion, or DNS behavior required for that mode
- **THEN** startup fails before readiness is reported
- **AND** the failure keeps the IPv6 prerequisite or route-validation gap
  explicit instead of silently degrading to a hidden IPv4-only tunnel

#### Scenario: Packaged host reaches dual-stack ready state only after both families succeed

- **GIVEN** a packaged host that claims one platform-tunnel mode can cover both
  IPv4 and IPv6 traffic families
- **WHEN** startup prepares the host adapter, route policy, and runtime attach
  for that mode
- **THEN** readiness is reported only after both address families satisfy the
  documented prerequisites
- **AND** partial success for one family does not masquerade as complete
  packaged system-tunnel coverage
