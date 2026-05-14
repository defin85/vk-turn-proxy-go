## MODIFIED Requirements
### Requirement: Desktop GUI shell supervises a compatible local host

The system SHALL ensure that the desktop GUI interacts only with a compatible
local host. The compatible host MAY be reached through a loopback sidecar
process or through a verified process-local embedded backend, but both backends
SHALL satisfy the same versioned control-plane contract before session,
provider, profile, or platform-tunnel management is enabled.

#### Scenario: Compatible host is not running or initialized

- **GIVEN** the desktop GUI starts and no compatible local host backend is
  available
- **WHEN** the GUI initializes runtime management
- **THEN** it starts, initializes, or prompts for a local host backend
  explicitly
- **AND** it does not attempt to manage sessions through an unavailable host

#### Scenario: Host version is incompatible

- **GIVEN** the desktop GUI finds a local host backend with an incompatible
  control-plane version
- **WHEN** compatibility negotiation runs
- **THEN** the GUI reports the incompatibility explicitly
- **AND** it blocks session management until a compatible host backend is
  available

#### Scenario: Embedded backend falls back to sidecar

- **GIVEN** a packaged desktop GUI is configured to prefer an embedded host
  backend
- **AND** embedded initialization fails before compatible negotiation succeeds
- **WHEN** a compatible sidecar host is available through the documented
  sidecar path
- **THEN** the GUI may fall back to the sidecar host
- **AND** diagnostics identify the selected backend and the embedded backend
  failure

#### Scenario: Embedded backend does not change shell workflows

- **GIVEN** the desktop GUI is connected to a compatible embedded host backend
- **WHEN** the operator manages providers, profiles, transport profiles,
  sessions, diagnostics, or platform tunnels
- **THEN** the GUI uses the same typed workflows it uses for a compatible
  sidecar host
- **AND** it does not branch into backend-specific provider, profile, or
  tunnel behavior
