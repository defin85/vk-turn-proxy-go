## ADDED Requirements
### Requirement: Native transport overlay exposes explicit ingress and egress adapters

The system SHALL support pluggable client ingress and server egress adapters above the existing provider-backed relay underlay.

#### Scenario: UDP baseline adapter pair preserves current behavior

- **GIVEN** a client runtime using `ingress=udp` and a server runtime using `egress=udp`
- **WHEN** the operator starts a supported session through the native overlay layer
- **THEN** the overlay preserves the current UDP forwarding semantics and compatibility expectations
- **AND** introducing the overlay layer does not require provider-specific changes

#### Scenario: Native TCP adapter pair creates isolated overlay streams

- **GIVEN** a client runtime using `ingress=tcp` and a server runtime using `egress=tcp`
- **WHEN** a local TCP connection is accepted on the client side
- **THEN** the runtimes create a distinct overlay stream identity for that connection
- **AND** the server side dials the configured upstream TCP target for that stream
- **AND** traffic for one stream does not reuse another stream's identity or teardown state

### Requirement: Native transport overlay distinguishes datagram and stream session classes

The system SHALL encode enough overlay metadata to preserve datagram reply routing and stream identity independently of the TURN/DTLS/plain underlay.

#### Scenario: Datagram adapter preserves datagram reply semantics

- **GIVEN** a supported UDP ingress adapter using a supported session
- **WHEN** datagrams are exchanged for the same local peer
- **THEN** the overlay preserves the current datagram reply target contract for that adapter
- **AND** it does not silently reinterpret datagrams as stream frames

#### Scenario: Stream teardown propagates across the overlay

- **GIVEN** a native TCP overlay stream with established local and upstream sockets
- **WHEN** either side closes or the relay path fails
- **THEN** the runtime closes the corresponding overlay stream and the paired local and upstream sockets
- **AND** stream cleanup does not terminate unrelated overlay sessions unless policy explicitly requires full-session failure

### Requirement: Unsupported adapter pairings fail closed

The system SHALL reject unsupported ingress and egress combinations before claiming readiness.

#### Scenario: Unsupported adapter combination

- **GIVEN** an ingress or egress adapter pairing that the runtime does not explicitly support
- **WHEN** the operator starts the client or server
- **THEN** the process exits non-zero with `policy_validate` or another documented startup stage
- **AND** it does not silently fall back to UDP-only forwarding

#### Scenario: Stream adapter is missing required session guarantees

- **GIVEN** a configured stream-class adapter that lacks required session identity, ordering, or teardown hooks
- **WHEN** runtime startup validates the adapter plan
- **THEN** startup fails before TURN allocation or peer setup begins

### Requirement: Native transport overlay requires deterministic evidence before support claims

The system SHALL back new adapter-pair support claims with deterministic tests or replayable compatibility evidence before documenting them as supported.

#### Scenario: New adapter pair becomes supported

- **GIVEN** a change that marks a new ingress and egress adapter pair as supported
- **WHEN** that change is merged
- **THEN** deterministic tests or replayable compatibility evidence cover startup, data transfer, and teardown for that pair
- **AND** docs and specs state any remaining limitations explicitly
