## ADDED Requirements

### Requirement: WireGuard-native remote ingress is protocol-specific

The system SHALL provision and document the remote UDP ingress for strict
`turn_datagram + wireguard_native` as a raw-WireGuard datagram endpoint, distinct
from DTLS/custom-overlay ingress unless an explicit UDP protocol multiplexer is
implemented and verified.

#### Scenario: DTLS overlay port is not reused implicitly

- **GIVEN** a deployed DTLS/custom-overlay listener on one external UDP port
- **WHEN** a strict `turn_datagram + wireguard_native` host materializes its
  remote endpoint
- **THEN** it targets a documented raw-WireGuard/plain ingress or a verified UDP
  protocol multiplexer
- **AND** it does not send raw WireGuard datagrams to a DTLS-only listener by
  default

#### Scenario: Shared port support depends on a demux contract

- **GIVEN** several clients use the same external UDP ingress
- **WHEN** those clients all speak the same documented ingress protocol
- **THEN** the server MAY serve them through the same listener using normal
  datagram/session routing
- **AND** multi-client support does not imply that the same listener accepts both
  DTLS overlay traffic and raw WireGuard datagrams without a documented
  multiplexer

### Requirement: WireGuard-native support claims require bidirectional remote data-plane evidence

The system SHALL treat packaged strict `wireguard_native` support as verified
only when evidence covers remote ingress reachability, a fresh WireGuard
handshake, and bidirectional data-plane traffic through the selected ingress.

#### Scenario: Local attach success is insufficient

- **GIVEN** a packaged host reports that the local platform tunnel adapter was
  attached
- **WHEN** the selected remote ingress does not accept raw WireGuard datagrams
- **THEN** the system does not claim end-to-end strict `wireguard_native` support
- **AND** diagnostics identify the missing remote data-plane evidence separately
  from local adapter attach

### Requirement: WireGuard-native material is not sourced from hidden app seeds

The system SHALL treat local WireGuard material as explicit host or app-owned
runtime state. Packaged app assets and workstation-local seed paths SHALL NOT be
used as an implicit source for strict `wireguard_native` materialization.

#### Scenario: Hidden packaged profile seed is ignored

- **GIVEN** a strict `wireguard_native` materializer is running inside a
  packaged client
- **WHEN** no explicit runtime WireGuard profile has been configured
- **THEN** the materializer fails closed
- **AND** it does not search for or load a hidden packaged `phone1.conf`
