## ADDED Requirements

### Requirement: Tunnel client starts a provider-backed session

The system SHALL start a real tunnel client session after resolving provider credentials, instead of stopping at provider-only credential resolution.

#### Scenario: Successful provider-backed startup

- **GIVEN** a supported client policy, a valid provider link, a configured local UDP listen address, and a configured peer server address
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system resolves provider credentials before starting transport
- **AND** binds the local UDP listener
- **AND** establishes one relay session to the configured peer using the resolved TURN credentials
- **AND** keeps the process running until cancellation or transport failure

### Requirement: Tunnel client forwards UDP traffic through the relay path

The system SHALL forward datagrams between the local UDP listener and the configured peer through the established client relay path.

#### Scenario: Bidirectional forwarding over the first runtime slice

- **GIVEN** an established client session and a reachable peer server
- **WHEN** a local application sends UDP datagrams to the client listen address
- **THEN** the client forwards them through the relay path to the configured peer
- **AND** datagrams received back from the peer are emitted to the local application
- **AND** provider-specific signaling state is not mixed into the forwarding logic

### Requirement: Tunnel client honors TURN endpoint overrides

The system SHALL allow operators to override the TURN endpoint while still using provider-resolved credentials.

#### Scenario: Override TURN host and port

- **GIVEN** provider-resolved credentials and operator-supplied `-turn` and/or `-port` flags
- **WHEN** the client starts a supported session
- **THEN** it uses the overridden TURN endpoint with the provider-resolved username and password
- **AND** it does not re-enter provider signaling to derive replacement credentials

### Requirement: Tunnel client fails closed on unsupported policy or startup errors

The system SHALL reject unsupported startup policies and surface transport-stage failures explicitly.

#### Scenario: Unsupported policy in the first runtime slice

- **GIVEN** `connections != 1`, `mode=tcp`, or `dtls=false`
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system fails before session startup with an explicit unsupported-config error
- **AND** it does not silently fall back to another transport policy

#### Scenario: Transport-stage startup failure

- **GIVEN** provider resolution succeeds but TURN allocation or DTLS handshake fails
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the system exits non-zero with an error that identifies the failing startup stage
- **AND** it cleans up the local listener and partially opened transport resources
