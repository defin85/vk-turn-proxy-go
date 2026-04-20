## ADDED Requirements
### Requirement: Generic TURN artifacts keep strict WireGuard carrier state internal

The system SHALL keep ordinary `generic_turn` artifact reads limited to
non-secret access methods and planning metadata even when a host can later
materialize a strict `turn_datagram` `wireguard_native` path from that artifact.

#### Scenario: Ordinary artifact reads do not expose a startable WireGuard lease

- **GIVEN** a resolved `generic_turn` artifact and a host build that can later
  start a strict `wireguard_native` plan with `carrier_family=turn_datagram`
- **WHEN** the host returns ordinary resolution reads or resolution events for
  that artifact
- **THEN** it advertises only `turn_credentials`, typed action metadata, and
  execution-planning fields
- **AND** it does not include raw WireGuard key material, peer configuration, or
  a startable carrier lease in the ordinary artifact payload

#### Scenario: Expired generic TURN artifact cannot imply a startable strict WireGuard path

- **GIVEN** a resolved `generic_turn` artifact whose credential or export
  lifetime has expired
- **WHEN** a caller inspects ordinary artifact state or requests same-device
  startup
- **THEN** the host does not imply that a strict `turn_datagram`
  `wireguard_native` path is still startable from that artifact
- **AND** it fails explicitly before materializing any secret-bearing carrier
  state
