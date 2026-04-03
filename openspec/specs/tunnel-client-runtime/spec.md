# tunnel-client-runtime Specification

## Purpose
Define the supported first-slice tunnel client runtime contract for one provider-backed UDP/DTLS relay session, explicit startup policy gating, reply routing, TURN overrides, and stage-aware startup failures.
## Requirements
### Requirement: Tunnel client validates the first-slice policy before provider resolution

The system SHALL validate the supported first-slice client policy before resolving provider credentials or starting transport resources.

#### Scenario: Supported first-slice policy

- **GIVEN** a client configuration with `connections=1`, `dtls=true`, `mode=udp|auto`, and an empty `bind-interface`
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system accepts the startup policy
- **AND** `mode=auto` normalizes to the UDP transport path for this slice
- **AND** provider resolution may proceed

#### Scenario: Unsupported first-slice policy

- **GIVEN** `connections != 1`, `mode=tcp`, `dtls=false`, or a non-empty `bind-interface`
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `policy_validate` as the failing stage
- **AND** it does not resolve provider credentials
- **AND** it does not bind the local listener or open TURN transport resources

### Requirement: Tunnel client starts a provider-backed session

The system SHALL start a real tunnel client session after resolving provider credentials, instead of stopping at provider-only credential resolution.

#### Scenario: Successful provider-backed startup

- **GIVEN** a supported client policy, a valid provider link, a configured local UDP listen address, and a configured peer server address
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system validates startup policy before provider resolution
- **AND** resolves provider credentials before starting transport
- **AND** binds the local UDP listener
- **AND** establishes one TURN allocation and one DTLS-backed relay session to the configured peer using the resolved TURN credentials
- **AND** keeps the process running until cancellation or transport failure

### Requirement: Tunnel client forwards UDP traffic through the relay path

The system SHALL forward datagrams between the local UDP listener and the configured peer through the established client relay path.

#### Scenario: Bidirectional forwarding over the first runtime slice

- **GIVEN** an established client session and a reachable peer server
- **WHEN** a local application sends UDP datagrams to the client listen address
- **THEN** the client forwards them through the relay path to the configured peer
- **AND** datagrams received back from the peer are emitted to the most recently observed local UDP source address for that session
- **AND** provider-specific signaling state is not mixed into the forwarding logic

#### Scenario: Reply target switches to the most recent local sender

- **GIVEN** an established client session and two local applications sending datagrams from different UDP source addresses
- **WHEN** the second application becomes the most recent sender to the client listen address
- **THEN** subsequent datagrams received from the peer are emitted to the second application's source address
- **AND** the first runtime slice does not claim multi-peer session demultiplexing

### Requirement: Tunnel client honors TURN endpoint overrides

The system SHALL allow operators to override the TURN endpoint while still using provider-resolved credentials.

#### Scenario: Override TURN host and port

- **GIVEN** provider-resolved credentials and operator-supplied `-turn` and/or `-port` flags
- **WHEN** the client starts a supported session
- **THEN** it uses the overridden TURN endpoint with the provider-resolved username and password
- **AND** it does not re-enter provider signaling to derive replacement credentials

### Requirement: Tunnel client surfaces stage-aware startup failures

The system SHALL surface provider and transport startup failures explicitly with stage-aware errors.

#### Scenario: Provider resolution failure

- **GIVEN** a supported first-slice policy and invalid provider input
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `provider_resolve` as the failing stage
- **AND** it does not bind the local listener or open TURN transport resources

#### Scenario: Transport-stage startup failure

- **GIVEN** provider resolution succeeds but TURN allocation or DTLS handshake fails
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `local_bind`, `turn_dial`, `turn_allocate`, `dtls_handshake`, or `forwarding_loop` as the failing stage
- **AND** it cleans up the local listener and partially opened transport resources
