## MODIFIED Requirements
### Requirement: Tunnel client validates the first-slice policy before provider resolution

The system SHALL validate the documented supervised client transport policy matrix, including the selected local ingress adapter, before resolving provider credentials or starting transport resources.

#### Scenario: Supported adapter-based transport policy

- **GIVEN** a client configuration with `connections >= 1`, a supported `ingress` adapter, `mode=udp|tcp|auto`, `dtls=true|false`, and adapter-specific local endpoint values that satisfy the selected adapter contract
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system accepts the startup policy
- **AND** `mode=auto` normalizes to the documented default TURN transport path for the selected provider/runtime slice
- **AND** provider resolution may proceed

#### Scenario: Unsupported adapter-based transport policy combination

- **GIVEN** an unsupported `ingress` adapter, missing adapter-specific endpoint requirement, or any combination outside the documented supported matrix
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `policy_validate` as the failing stage
- **AND** it does not resolve provider credentials
- **AND** it does not bind local adapter resources or open TURN transport resources

### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path that corresponds to the accepted supervised client transport and overlay-adapter policy.

#### Scenario: Successful supervised startup

- **GIVEN** a supported client policy with a configured `connections` count and a supported local ingress adapter
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system resolves provider credentials before starting transport
- **AND** binds the selected local ingress adapter endpoint
- **AND** starts the configured number of supervised transport workers for the selected TURN and peer modes
- **AND** initializes any adapter-specific session manager needed for the selected ingress adapter before reporting readiness
- **AND** it reports a single session identity across those workers
