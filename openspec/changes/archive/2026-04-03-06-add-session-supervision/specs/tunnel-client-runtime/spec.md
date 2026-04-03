## MODIFIED Requirements

### Requirement: Tunnel client validates the first-slice policy before provider resolution

The system SHALL validate the documented supervised client transport policy matrix before resolving provider credentials or starting transport resources.

#### Scenario: Supported supervised transport policy

- **GIVEN** a client configuration with `connections >= 1`, a UDP local listener, `mode=udp|tcp|auto`, `dtls=true|false`, and either an empty `bind-interface` or a supported literal local IP bind target
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system accepts the startup policy
- **AND** `mode=auto` normalizes to the documented default TURN transport path for the selected provider/runtime slice
- **AND** provider resolution may proceed

#### Scenario: Unsupported transport policy combination

- **GIVEN** `connections <= 0`, a non-IP `bind-interface` value, or any combination outside the documented supported matrix
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `policy_validate` as the failing stage
- **AND** it does not resolve provider credentials
- **AND** it does not bind the local listener or open TURN transport resources

### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path that corresponds to the accepted supervised client transport policy.

#### Scenario: Successful supervised startup

- **GIVEN** a supported client policy with a configured `connections` count
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system resolves provider credentials before starting transport
- **AND** binds one shared local UDP listener for the session
- **AND** starts the configured number of supervised transport workers for the selected TURN and peer modes
- **AND** it reports a single session identity across those workers

### Requirement: Tunnel client forwards UDP traffic through the relay path

The system SHALL forward datagrams between the local UDP listener and the configured UDP peer through the established relay path for the accepted supervised client policy.

#### Scenario: Bidirectional forwarding over a supervised transport policy

- **GIVEN** an established supervised client session for a documented supported transport policy
- **WHEN** local applications send UDP datagrams to the client listen address
- **THEN** the session dispatches those datagrams across ready workers without binding additional local listeners
- **AND** datagrams received back from a worker are emitted to that worker's most recently observed local UDP source address
- **AND** the supervised session does not claim stable multi-peer reply demultiplexing across all workers

### Requirement: Tunnel client surfaces stage-aware startup failures

The system SHALL surface provider, transport, and supervised lifecycle failures explicitly with stage-aware errors for the accepted transport path.

#### Scenario: Supervised worker restart budget is exhausted

- **GIVEN** a running supervised client session and a worker that keeps failing after readiness
- **WHEN** the supervisor exhausts the documented restart budget for that worker
- **THEN** the system exits non-zero with an error that identifies `session_supervision` as the failing stage
- **AND** it cleans up the shared local listener and all partially running workers
