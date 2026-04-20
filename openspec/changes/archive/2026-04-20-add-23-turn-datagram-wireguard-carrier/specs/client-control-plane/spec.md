## ADDED Requirements
### Requirement: Client control plane keeps strict WireGuard carrier material host-owned

The system SHALL let the host materialize and consume secret-bearing carrier
state for strict `turn_datagram` `wireguard_native` startup without serializing
that state through ordinary shell-facing control-plane reads.

#### Scenario: Host starts a strict WireGuard path without exporting the carrier lease

- **GIVEN** a resolved `generic_turn` artifact and a selected same-device
  execution plan with `carrier_family=turn_datagram` and
  `engine_family=wireguard_native`
- **WHEN** a shell requests same-device startup through the control plane
- **THEN** the host materializes and consumes any required strict WireGuard
  carrier state internally
- **AND** the control plane returns only typed session, resolution, or platform
  tunnel state
- **AND** the shell does not receive raw private keys, peer keys, or other
  startable carrier-secret material in ordinary API responses

#### Scenario: Host lacks the strict WireGuard materializer or carrier

- **GIVEN** a host build that can expose the requested platform adapter mode but
  does not implement the documented strict `turn_datagram` `wireguard_native`
  materializer or carrier
- **WHEN** a shell requests same-device startup through the control plane
- **THEN** the host fails explicitly before `ready=true`
- **AND** it reports the requested execution plan as unavailable or unsupported
- **AND** it does not silently fall back to the current overlay runtime
