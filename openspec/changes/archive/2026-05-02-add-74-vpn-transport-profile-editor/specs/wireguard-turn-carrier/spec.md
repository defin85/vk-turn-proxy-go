## ADDED Requirements

### Requirement: WireGuard carrier consumes structured profile material

The WireGuard TURN carrier SHALL materialize accepted structured
`wireguard_native_v1` profile fields through the same execution lease path used
by imported WireGuard profiles.

#### Scenario: Structured profile starts WireGuard carrier

- **GIVEN** a `wireguard_native_v1` profile was created or updated through the
  structured editor
- **AND** the profile is compatible with a strict TURN datagram WireGuard
  execution plan
- **WHEN** platform tunnel startup materializes a WireGuard execution lease
- **THEN** the lease uses the stored profile id as its transport-profile source
- **AND** accepted interface addresses, peer public key, allowed IPs, DNS
  servers, MTU, endpoint source, and supported optional fields are reflected in
  the lease
- **AND** startup responses remain redacted

#### Scenario: Accepted field cannot be materialized

- **GIVEN** the host advertises a structured WireGuard field as supported
- **AND** the operator saves that field in a valid profile
- **WHEN** startup materialization cannot apply that field to the selected
  carrier or host adapter
- **THEN** startup fails closed with a transport-profile validation failure
- **AND** the host does not silently drop the field while reporting readiness
