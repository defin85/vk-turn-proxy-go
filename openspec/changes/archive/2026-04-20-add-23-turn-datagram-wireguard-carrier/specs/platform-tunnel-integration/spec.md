## ADDED Requirements
### Requirement: Platform tunnel readiness depends on the documented carrier as well as the host adapter

The system SHALL require the documented strict carrier and execution
materialization prerequisites for a packaged `wireguard_native` platform tunnel
mode in addition to the OS-specific tunnel primitive.

#### Scenario: Host adapter exists but the strict WireGuard carrier is missing

- **GIVEN** a packaged host can acquire the OS tunnel primitive for one
  platform mode such as `android_vpn_service` or `windows_wintun`
- **AND** the host does not implement the documented strict `turn_datagram`
  `wireguard_native` carrier or its execution-materialization step
- **WHEN** startup validates the requested execution plan for that mode
- **THEN** startup fails before `ready=true`
- **AND** the failure keeps the requested execution plan explicit
- **AND** the host does not silently reuse the current overlay runtime as if it
  were the same platform-tunnel path

#### Scenario: Packaged host reaches ready state only after strict carrier attach

- **GIVEN** a packaged host has prepared routes and established the OS tunnel
  primitive for one strict `wireguard_native` mode
- **WHEN** the host attaches the documented strict `turn_datagram`
  `wireguard_native` carrier successfully
- **THEN** readiness is reported only after that carrier attach succeeds
- **AND** the host may claim support for that mode only on builds that satisfy
  both the adapter and carrier prerequisites
