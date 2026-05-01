## ADDED Requirements

### Requirement: Control plane exposes RelayDock-owned native VPN lifecycle actions

The client control plane SHALL expose native VPN setup, start, resume, status,
and stop actions without leaking Android-specific APIs or raw profile secrets
into Flutter shell state.

#### Scenario: Shell starts native VPN through canonical control plane

- **GIVEN** the shell has selected a structured VPN transport profile
- **AND** a resolved TURN artifact is available for startup
- **WHEN** the shell requests native VPN startup
- **THEN** the control plane accepts profile and artifact references rather than
  raw secret material
- **AND** it returns a typed startup attempt, current lifecycle state, and any
  required operator action
- **AND** it fails before native bring-up when the referenced profile or
  artifact is missing, expired, incompatible, or no longer authorized for the
  selected runtime plan
- **AND** it does not expose Android `VpnService` objects or platform-channel
  details to the shell

#### Scenario: Shell resumes after Android permission

- **GIVEN** a native Android startup attempt is waiting for VPN permission
- **WHEN** the operator grants permission and the shell resumes the attempt
- **THEN** the control plane continues the same startup attempt
- **AND** it reports ready only after the host completes native runtime attach
- **AND** it reports a failed or blocked state if permission is denied or
  cancelled

#### Scenario: Shell stops native VPN through canonical control plane

- **GIVEN** a native VPN attempt is starting or ready
- **WHEN** the shell requests stop
- **THEN** the control plane routes stop to the embedded host
- **AND** it exposes the resulting stopped or failed lifecycle state
- **AND** it keeps diagnostics associated with the attempt

### Requirement: Control plane distinguishes native VPN lifecycle states

The client control plane SHALL report lifecycle states precise enough for the
mobile GUI to present setup, permission, starting, ready, stopping, stopped, and
failed native VPN states.

#### Scenario: Native lifecycle state is queryable

- **GIVEN** the operator opens the mobile shell while a native VPN attempt
  exists
- **WHEN** the shell queries current control-plane state
- **THEN** the response identifies whether setup is needed, permission is
  pending, startup is in progress, VPN is ready, stop is in progress, the
  attempt is stopped, or the attempt failed
- **AND** the response identifies the selected profile, platform tunnel mode,
  scope policy, session identity when available, and actionable diagnostics

#### Scenario: Native lifecycle state survives shell restart

- **GIVEN** the Flutter shell process restarts or returns to foreground while a
  native VPN attempt is active, stopped, failed, or revoked
- **WHEN** the shell queries the control plane
- **THEN** the response is derived from host-owned lifecycle state
- **AND** the shell can recover the current state without relying on a
  previously cached local startup result
