## ADDED Requirements
### Requirement: Client control plane exposes typed underlay-route policy support for platform tunnels

The system SHALL expose supported underlay-route policies through the local
control-plane contract so shells can request development-safe local-network
preservation without guessing host-specific behavior.

#### Scenario: Host advertises development underlay-route policy support

- **GIVEN** a compatible host that supports preserving the active local network
  for `android_vpn_service`
- **WHEN** a shell inspects the typed platform-tunnel capability metadata
- **THEN** the host advertises that underlay-route policy explicitly for that
  mode
- **AND** the shell does not need to infer support from package-routing fields
  or Android-version heuristics alone

#### Scenario: Shell starts a platform tunnel with a typed underlay-route policy

- **GIVEN** a shell requests platform tunnel startup through the local control
  plane
- **WHEN** it needs the development local-network-preserving profile
- **THEN** the startup request carries a typed `underlay_route_policy` value
- **AND** the host validates that value through the same versioned contract
  instead of treating it as an untyped Android-only hint

#### Scenario: Older or incompatible host lacks typed underlay-route policy support

- **GIVEN** a shell build that expects typed underlay-route policy support
- **WHEN** it negotiates with an older or incompatible host that does not
  advertise that capability
- **THEN** the shell can fail closed or suppress the unsupported workflow
  explicitly
- **AND** the control plane does not silently reinterpret the request as the
  default routing profile
