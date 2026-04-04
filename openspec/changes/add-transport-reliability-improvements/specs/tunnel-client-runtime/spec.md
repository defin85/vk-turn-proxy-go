## MODIFIED Requirements
### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path that corresponds to the accepted supervised client transport policy.

#### Scenario: Successful supervised startup

- **GIVEN** a supported client policy with a configured `connections` count
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system resolves provider credentials before starting transport
- **AND** binds one shared local UDP listener for the session
- **AND** starts the configured number of supervised transport workers for the selected TURN and peer modes
- **AND** it reports a single session identity across those workers

#### Scenario: Long-lived supported session keeps transport maintenance active

- **GIVEN** a supported client policy whose provider resolution and transport startup succeed
- **AND** the TURN allocation remains active long enough to require normal maintenance behavior
- **WHEN** the runtime keeps the session alive through that maintenance window
- **THEN** the transport path remains usable without recreating the whole session
- **AND** the runtime does not silently widen provider behavior or transport policy to achieve that result

### Requirement: Tunnel client surfaces stage-aware startup failures

The system SHALL surface provider, transport, and supervised lifecycle failures explicitly with stage-aware errors for the accepted transport path.

#### Scenario: Reliability plumbing fails during startup

- **GIVEN** a supported client policy whose transport path depends on the improved TURN client plumbing
- **WHEN** that plumbing fails before the worker becomes ready
- **THEN** the client exits non-zero with the responsible transport stage
- **AND** it releases partial local and TURN resources before returning
