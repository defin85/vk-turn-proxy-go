## ADDED Requirements
### Requirement: Client control plane exposes typed address-family coverage for platform tunnels

The system SHALL expose typed address-family coverage metadata for supported
platform-tunnel modes and their startup results so shells do not infer
dual-stack support from `ready=true` or free-form message text alone.

#### Scenario: Host advertises IPv4-only coverage explicitly

- **GIVEN** a compatible host that can prepare one platform-tunnel mode only
  for IPv4 traffic
- **WHEN** a shell inspects the typed platform-tunnel capability or startup
  metadata
- **THEN** the host reports that IPv4-only coverage explicitly
- **AND** the shell does not need to reverse-engineer that limitation from
  untyped warning text or platform-specific heuristics

#### Scenario: Older or incomplete hosts do not imply dual-stack support

- **GIVEN** a shell build that expects typed address-family coverage metadata
- **WHEN** it negotiates with an older or incomplete host that does not provide
  enough typed coverage information for dual-stack claims
- **THEN** the shell may suppress or downgrade dual-stack full-tunnel claims
  explicitly
- **AND** the control plane does not silently reinterpret missing metadata as
  proof of IPv6 support
