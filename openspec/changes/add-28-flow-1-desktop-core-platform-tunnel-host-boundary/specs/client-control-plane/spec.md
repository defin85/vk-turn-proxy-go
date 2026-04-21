## ADDED Requirements
### Requirement: Client control plane remains the canonical packaged desktop tunnel startup API

The system SHALL keep packaged desktop tunnel startup under the same versioned
client-control-plane contract instead of introducing a parallel desktop-helper
startup protocol for shells.

#### Scenario: Packaged desktop build starts system tunnel through the control plane

- **GIVEN** a packaged desktop build with one documented system-tunnel mode
- **WHEN** the desktop shell requests startup
- **THEN** it uses the versioned local control-plane contract as the canonical
  API surface
- **AND** the host coordinates any native desktop adapter work behind that
  contract instead of exposing a second startup API to the shell

### Requirement: Shared desktop startup semantics remain stage-oriented instead of OS-API-oriented

The system SHALL keep the packaged desktop system-tunnel boundary expressed in
typed startup stages and prerequisites instead of direct Windows-, Linux-, or
Apple-specific API objects.

#### Scenario: Shared control-plane contract is reused by a future desktop adapter

- **GIVEN** a future packaged desktop host that implements a different native
  adapter from the first shipped desktop mode
- **WHEN** that host reuses the packaged startup contract
- **THEN** the client-control-plane surface still uses typed stages,
  prerequisites, and ready/failure state
- **AND** it does not require Flutter shells or the Go control plane to speak
  one OS adapter's APIs directly
