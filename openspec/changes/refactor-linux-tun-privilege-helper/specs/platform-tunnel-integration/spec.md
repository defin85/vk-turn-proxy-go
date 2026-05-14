## ADDED Requirements
### Requirement: Linux privilege acquisition is a platform-tunnel startup stage

The system SHALL treat Linux `linux_tun` privilege acquisition as part of the
typed platform-tunnel startup flow, not as a prerequisite for ordinary local
host startup.

#### Scenario: Linux privilege is unavailable while local host remains available

- **GIVEN** a packaged Linux desktop host whose user-space local control plane
  is reachable
- **AND** the current desktop session cannot complete helper privilege
  acquisition
- **WHEN** the operator starts `linux_tun`
- **THEN** startup returns `ready=false`
- **AND** the result reports `permission_acquire` as the failing stage and
  `permission` as the missing prerequisite
- **AND** `/v1/host` remains reachable for profiles, provider resolution,
  diagnostics, and retrying the platform-tunnel startup

#### Scenario: Local host startup does not claim Linux tunnel readiness

- **GIVEN** the packaged Linux local host starts without elevated privilege
- **WHEN** the shell negotiates capabilities
- **THEN** the host may report the documented `linux_tun` execution plan only
  according to the installed helper and package prerequisites
- **AND** it does not report the `permission` prerequisite as satisfied before
  a helper startup attempt has actually acquired Linux privilege
- **AND** it does not claim `ready=true` for a platform tunnel until the
  helper has completed native bring-up and runtime attach for a startup
  attempt

#### Scenario: Helper startup failure stays stage-aware

- **GIVEN** a packaged Linux host invokes the privileged helper for
  `linux_tun`
- **WHEN** the helper binary is missing, malformed, denied, or exits before
  accepting the startup payload
- **THEN** the host reports a typed platform-tunnel failure at the appropriate
  documented stage
- **AND** it does not collapse the failure into a generic local-host
  incompatibility or a fake session state

#### Scenario: Helper crash does not block the local host

- **GIVEN** a packaged Linux host has started a `linux_tun` attempt through
  the privileged helper
- **WHEN** the helper exits unexpectedly during startup or while it owns active
  native tunnel state
- **THEN** the host reports typed platform-tunnel failure or stopped state with
  cleanup diagnostics
- **AND** `/v1/host` remains reachable for diagnostics, profile repair,
  provider resolution, and a later retry
