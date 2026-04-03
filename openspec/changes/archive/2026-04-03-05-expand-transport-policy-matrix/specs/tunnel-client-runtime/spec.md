## MODIFIED Requirements

### Requirement: Tunnel client validates the first-slice policy before provider resolution

The system SHALL validate the documented supported one-session client transport policy matrix before resolving provider credentials or starting transport resources.

#### Scenario: Supported one-session transport policy

- **GIVEN** a client configuration with `connections=1`, a UDP local listener, `mode=udp|tcp|auto`, `dtls=true|false`, and either an empty `bind-interface` or a supported literal local IP bind target
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system accepts the startup policy
- **AND** `mode=auto` normalizes to the documented default TURN transport path for the selected provider/runtime slice
- **AND** provider resolution may proceed

#### Scenario: Unsupported transport policy combination

- **GIVEN** `connections != 1`, a non-IP `bind-interface` value, or any combination outside the documented supported matrix
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `policy_validate` as the failing stage
- **AND** it does not resolve provider credentials
- **AND** it does not bind the local listener or open TURN transport resources

### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path that corresponds to the accepted one-session client transport policy.

#### Scenario: TURN over UDP with DTLS

- **GIVEN** a supported client policy with `mode=udp|auto` and `dtls=true`
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system resolves provider credentials before starting transport
- **AND** binds the local UDP listener
- **AND** uses UDP to the TURN server
- **AND** allocates one TURN relay and establishes one DTLS-backed relay session to the configured UDP peer

#### Scenario: TURN over TCP with DTLS

- **GIVEN** a supported client policy with `mode=tcp` and `dtls=true`
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system uses TCP between the client and the TURN server
- **AND** wraps the stream-oriented TURN hop with TURN/STUN framing
- **AND** allocates one TURN relay and establishes one DTLS-backed relay session to the configured UDP peer
- **AND** it does not silently fall back to UDP

#### Scenario: Plain relay without DTLS

- **GIVEN** a supported client policy with `dtls=false`
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system allocates one TURN relay using the selected TURN transport mode
- **AND** forwards plain datagrams between that relay allocation and the configured UDP peer
- **AND** it does not initiate a DTLS handshake

### Requirement: Tunnel client forwards UDP traffic through the relay path

The system SHALL forward datagrams between the local UDP listener and the configured UDP peer through the established relay path for the accepted client policy.

#### Scenario: Bidirectional forwarding over an accepted transport policy

- **GIVEN** an established client session for a documented supported transport policy
- **WHEN** a local application sends UDP datagrams to the client listen address
- **THEN** the client forwards them through the selected relay path to the configured peer
- **AND** datagrams received back from the peer are emitted to the most recently observed local UDP source address for that session
- **AND** provider-specific signaling state is not mixed into the forwarding logic

#### Scenario: Reply target switches to the most recent local sender

- **GIVEN** an established client session and two local applications sending datagrams from different UDP source addresses
- **WHEN** the second application becomes the most recent sender to the client listen address
- **THEN** subsequent datagrams received from the peer are emitted to the second application's source address
- **AND** the accepted one-session policy does not claim multi-peer session demultiplexing

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

The system SHALL surface provider and transport startup failures explicitly with stage-aware errors for the accepted transport path.

#### Scenario: Provider resolution failure

- **GIVEN** a supported one-session client policy and invalid provider input
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `provider_resolve` as the failing stage
- **AND** it does not bind the local listener or open TURN transport resources

#### Scenario: Transport-stage startup failure

- **GIVEN** provider resolution succeeds but outbound bind, TURN dial/allocation, transport-neutral peer setup, or DTLS handshake fails for the accepted client policy
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `local_bind`, `turn_dial`, `turn_allocate`, `peer_setup`, `dtls_handshake`, or `forwarding_loop` as the failing stage
- **AND** it cleans up the local listener and partially opened transport resources
