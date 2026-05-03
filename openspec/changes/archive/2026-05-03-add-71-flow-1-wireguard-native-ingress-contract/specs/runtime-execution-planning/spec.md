## ADDED Requirements

### Requirement: TURN-backed execution plans identify the remote ingress protocol

The system SHALL include the remote ingress protocol role in TURN-backed
execution plans so host materialization can distinguish DTLS/custom-overlay
endpoints from raw-WireGuard ingress endpoints.

#### Scenario: WireGuard-native plan selects raw-WireGuard ingress

- **GIVEN** a packaged system-tunnel plan with `carrier_family=turn_datagram` and
  `engine_family=wireguard_native`
- **WHEN** the host materializes remote endpoint details for runtime startup
- **THEN** the endpoint role is raw-WireGuard datagram ingress or a verified UDP
  protocol multiplexer that accepts raw WireGuard traffic
- **AND** the DTLS/custom-overlay endpoint remains scoped to the
  `turn_dtls_overlay + custom_packet_overlay` path

#### Scenario: Protocol mismatch fails closed before readiness

- **GIVEN** a strict `wireguard_native` plan whose selected remote endpoint is
  known to be DTLS-only
- **WHEN** no explicit UDP protocol multiplexer is configured for that endpoint
- **THEN** runtime planning or host materialization fails closed before reporting
  platform-tunnel readiness
- **AND** the diagnostic names the expected and actual remote ingress protocols

#### Scenario: Android plan remains blocked until explicit local material exists

- **GIVEN** an Android `android_vpn_service` plan with `carrier_family=turn_datagram`
  and `engine_family=wireguard_native`
- **AND** no app-owned WireGuard profile has been imported at runtime
- **WHEN** the mobile shell prepares startup
- **THEN** the plan is surfaced as setup-needed rather than ready-to-start
- **AND** startup does not depend on hidden packaged profile assets
