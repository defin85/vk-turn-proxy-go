# tunnel-client-runtime Specification

## Purpose
Define the supported one-session tunnel client runtime contract for provider-backed UDP or TCP TURN transport, DTLS or plain relay paths, outbound bind targets, reply routing, explicit startup policy gating, and stage-aware startup failures.
## Requirements
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

### Requirement: Tunnel client forwards UDP traffic through the relay path

The system SHALL forward datagrams between the local UDP listener and the configured UDP peer through the established relay path for the accepted supervised client policy.

#### Scenario: Bidirectional forwarding over a supervised transport policy

- **GIVEN** an established supervised client session for a documented supported transport policy
- **WHEN** local applications send UDP datagrams to the client listen address
- **THEN** the session dispatches those datagrams across ready workers without binding additional local listeners
- **AND** datagrams received back from a worker are emitted to that worker's most recently observed local UDP source address
- **AND** the supervised session does not claim stable multi-peer reply demultiplexing across all workers

### Requirement: Tunnel client honors TURN endpoint overrides

The system SHALL honor operator-supplied TURN endpoint overrides and supported outbound bind targets while still using provider-resolved credentials.

#### Scenario: Override TURN host and port

- **GIVEN** provider-resolved credentials and operator-supplied `-turn` and/or `-port` flags
- **WHEN** the client starts a supported session
- **THEN** it uses the overridden TURN endpoint with the provider-resolved username and password
- **AND** it does not re-enter provider signaling to derive replacement credentials

#### Scenario: Supported literal local IP bind target

- **GIVEN** a supported client policy with `bind-interface` set to a literal local IP address
- **WHEN** outbound TURN transport setup starts
- **THEN** the runtime binds or dials the TURN transport using that local source address
- **AND** the local application listener remains bound to the configured `-listen` address

#### Scenario: Bind target cannot be applied

- **GIVEN** a supported client policy with a literal local IP bind target that cannot actually be used for outbound TURN setup
- **WHEN** the runtime starts outbound transport setup
- **THEN** the system exits non-zero with an error that identifies `turn_dial` or another documented outbound-setup stage
- **AND** it does not silently retry with an implicit fallback bind target

### Requirement: Tunnel client surfaces stage-aware startup failures

The system SHALL surface provider, transport, and supervised lifecycle failures explicitly with stage-aware errors for the accepted transport path.

#### Scenario: Reliability plumbing fails during startup

- **GIVEN** a supported client policy whose transport path depends on the improved TURN client plumbing
- **WHEN** that plumbing fails before the worker becomes ready
- **THEN** the client exits non-zero with the responsible transport stage
- **AND** it releases partial local and TURN resources before returning

