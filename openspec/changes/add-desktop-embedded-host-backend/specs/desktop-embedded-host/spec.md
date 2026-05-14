## ADDED Requirements
### Requirement: Desktop embedded host is an optional packaged host backend

Packaged desktop builds SHALL be allowed to use a process-local embedded host
backend only as an implementation choice behind the same desktop host contract
used by the loopback sidecar. Embedded mode SHALL NOT remove the supported
sidecar `clientd` path until a later reviewed change explicitly does so.

#### Scenario: Packaged shell selects a compatible embedded host

- **GIVEN** a packaged desktop shell includes a verified embedded host backend
- **WHEN** the shell initializes runtime management
- **THEN** it may initialize the embedded backend before launching a sidecar
- **AND** it treats the backend as ready only after version and capability
  negotiation succeeds through the canonical host contract

#### Scenario: Embedded backend is unavailable

- **GIVEN** a packaged desktop shell whose embedded backend is disabled,
  missing, incompatible, or fails during initialization
- **WHEN** the shell initializes runtime management
- **THEN** it may fall back to the documented loopback sidecar path
- **AND** diagnostics record the embedded backend failure or disabled state
  without reporting a false provider, profile, or tunnel failure

### Requirement: Embedded host preserves canonical control-plane semantics

The embedded desktop host backend SHALL expose the same versioned host
semantics as the loopback `clientd` path for host info, negotiation,
capabilities, provider resolution, profiles, transport profiles, sessions,
challenges, platform tunnels, event streaming, and diagnostics.

#### Scenario: Shell uses one host abstraction across backends

- **GIVEN** the desktop shell can use either embedded host or loopback sidecar
- **WHEN** it performs host operations after negotiation
- **THEN** it uses the same shell-facing control-plane abstraction for both
  backends
- **AND** backend-specific transport details do not leak into provider,
  profile, routing, diagnostics, or tunnel UI workflows

#### Scenario: Embedded backend drifts from sidecar contract

- **GIVEN** an embedded backend omits a required capability, changes error
  shape, or cannot stream equivalent typed events
- **WHEN** the shell negotiates with that backend
- **THEN** the shell rejects it as incompatible or falls back to sidecar
- **AND** it does not silently continue with partial host semantics

### Requirement: Embedded host preserves native privilege boundaries

The embedded desktop host backend SHALL keep native tunnel primitives and
privilege acquisition inside the packaged host boundary. Flutter UI code SHALL
remain a typed consumer of host state and SHALL NOT directly own OS route,
DNS, driver, TUN, packet-capture, or privileged cleanup operations.

#### Scenario: Embedded desktop host starts a platform tunnel

- **GIVEN** a desktop shell is using the embedded host backend
- **WHEN** the operator starts a documented platform tunnel mode
- **THEN** startup still flows through the canonical host-owned platform
  tunnel contract
- **AND** typed startup stages, missing prerequisites, diagnostics, and
  cleanup semantics match the sidecar host contract

#### Scenario: Linux embedded mode reaches privileged tunnel work

- **GIVEN** a Linux packaged desktop shell uses or experiments with an embedded
  host backend
- **WHEN** `linux_tun` startup needs privileged TUN, route, DNS, or cleanup
  work
- **THEN** the host reaches that privilege through the documented helper
  boundary
- **AND** the GUI process is not required to run as root
