## ADDED Requirements
### Requirement: Packaged Linux hosts can establish a ready `linux_tun` path for the documented Ubuntu target

The system SHALL support one concrete desktop platform-tunnel ready path for
the documented Ubuntu packaged target through `linux_tun`.

#### Scenario: Packaged Linux host reaches ready state

- **GIVEN** a packaged Linux desktop host that includes the documented
  `linux_tun` implementation for the supported Ubuntu target
- **AND** the required helper privilege mediation succeeds
- **WHEN** the operator starts system tunnel mode for `linux_tun`
- **THEN** startup returns `ready=true` for `linux_tun`
- **AND** the host reports readiness only after route validation, host
  bring-up, runtime attach, and dataplane verification succeed

#### Scenario: Linux helper privilege is denied

- **GIVEN** a packaged Linux host that requires helper privilege mediation
  before `linux_tun` can start
- **WHEN** the operator denies that mediation during startup
- **THEN** startup returns `ready=false`
- **AND** it reports `permission_acquire` as the failing stage
- **AND** it reports `permission` as the missing prerequisite

### Requirement: Linux `linux_tun` startup protects control traffic and cleans up on failure

The system SHALL validate Linux underlay preservation before claiming
readiness, and SHALL tear down partial Linux-native resources when startup
fails after partial progress.

#### Scenario: Linux underlay preservation is unsafe

- **GIVEN** a packaged Linux host starting `linux_tun`
- **AND** the documented control-plane, provider-challenge, or required
  underlay exclusions cannot be prepared safely
- **WHEN** startup validates the Linux route policy
- **THEN** startup returns `ready=false`
- **AND** it reports `route_validate` as the failing stage
- **AND** it reports `route_exclusion` or `dns_bypass` as the missing
  prerequisite
- **AND** the host does not claim readiness

#### Scenario: Runtime attach fails after Linux host bring-up

- **GIVEN** a packaged Linux host that has already created the TUN interface
  and prepared the documented route policy
- **WHEN** the host cannot attach the shared runtime to that `linux_tun` path
- **THEN** startup returns `ready=false`
- **AND** it reports `runtime_attach` as the failing stage
- **AND** the host tears down the partial Linux-native resources before
  returning failure
