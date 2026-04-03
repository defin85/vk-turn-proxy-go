## MODIFIED Requirements

### Requirement: Tunnel client validates the supported transport policy matrix before provider resolution

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

### Requirement: Tunnel client starts the provider-backed transport path for the accepted policy

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

### Requirement: Tunnel client forwards UDP traffic through the accepted relay path

The system SHALL forward datagrams between the local UDP listener and the configured UDP peer through the established relay path for the accepted client policy.

#### Scenario: Bidirectional forwarding over an accepted transport policy

- **GIVEN** an established client session for a documented supported transport policy
- **WHEN** a local application sends UDP datagrams to the client listen address
- **THEN** the client forwards them through the selected relay path to the configured peer
- **AND** datagrams received back from the peer are emitted to the most recently observed local UDP source address for that session
- **AND** provider-specific signaling state is not mixed into the forwarding logic

### Requirement: Tunnel client honors supported outbound bind targets

The system SHALL apply the supported outbound bind target to TURN transport setup without changing provider resolution or local UDP listen semantics.

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

#### Scenario: Transport-stage startup failure

- **GIVEN** provider resolution succeeds but outbound bind, TURN dial/allocation, transport-neutral peer setup, or DTLS handshake fails for the accepted client policy
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies `local_bind`, `turn_dial`, `turn_allocate`, `peer_setup`, `dtls_handshake`, or `forwarding_loop` as the failing stage
- **AND** it cleans up the local listener and partially opened transport resources
