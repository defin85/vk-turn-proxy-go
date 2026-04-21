## ADDED Requirements
### Requirement: Packaged system-tunnel support claims are address-family-scoped

The system SHALL scope packaged system-tunnel support claims to the traffic
address families that the documented execution plan can actually carry.

#### Scenario: IPv4-ready packaged path does not imply dual-stack support

- **GIVEN** a packaged host can reach `ready=true` for one documented
  `turn_datagram + wireguard_native` platform-tunnel mode
- **AND** that mode only prepares or verifies IPv4 tunnel addresses, routes, or
  exclusions
- **WHEN** the host reports or the repository documents the supported packaged
  execution plan for that mode
- **THEN** the support claim remains explicit that the path is not yet a
  complete dual-stack packaged system tunnel
- **AND** the host does not imply that IPv6 traffic is routed through the same
  plan by default

#### Scenario: Dual-stack packaged support claim requires explicit IPv6 evidence

- **GIVEN** a packaged host reports one platform-tunnel mode as supporting both
  IPv4 and IPv6 traffic families
- **WHEN** that support claim is documented or shipped
- **THEN** repo-owned evidence covers carrier materialization, route
  preparation, underlay exclusions, and egress verification for both families
- **AND** `ready=true` for an IPv4-only path is not treated as equivalent proof
