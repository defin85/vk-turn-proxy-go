## ADDED Requirements
### Requirement: Client control plane remains the canonical Android VPN startup API

The system SHALL keep Android packaged VPN startup under the same versioned
client-control-plane contract instead of introducing a parallel Flutter-only or
Android-only startup protocol.

#### Scenario: Packaged Android build starts system tunnel through the control plane

- **GIVEN** a packaged Android build with the documented `android_vpn_service`
  path
- **WHEN** the mobile shell requests startup
- **THEN** it uses the versioned local control-plane contract as the canonical
  API surface
- **AND** the host coordinates any native Android adapter work behind that
  contract instead of exposing a second tunnel startup API to the shell

### Requirement: Shared startup semantics remain stage-oriented instead of Android-API-oriented

The system SHALL keep the packaged mobile system-tunnel boundary expressed in
typed startup stages and prerequisites instead of direct Android API objects or
method names.

#### Scenario: Shared control-plane contract is reused by a future mobile adapter

- **GIVEN** a future packaged mobile host that implements a different native
  adapter from Android `VpnService`
- **WHEN** that host reuses the packaged startup contract
- **THEN** the client-control-plane surface still uses typed stages,
  prerequisites, and ready/failure state
- **AND** it does not require Flutter shells or the embedded Go host to speak
  Android-specific `VpnService` APIs directly
