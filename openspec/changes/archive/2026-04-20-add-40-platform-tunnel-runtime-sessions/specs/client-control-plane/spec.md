## ADDED Requirements

### Requirement: Client control plane publishes runtime-backed platform tunnels through ordinary sessions

The system SHALL expose any runtime-backed platform-tunnel startup that reaches
`ready=true` through the ordinary typed session surface instead of leaving that
runtime visible only through tunnel-specific state.

#### Scenario: Ready platform-tunnel startup creates a session

- **GIVEN** a local shell starts a supported platform-tunnel mode through the
  control plane
- **AND** that startup reaches `ready=true` after runtime attach succeeds
- **WHEN** the shell reads the resulting typed control-plane state
- **THEN** the control plane publishes an ordinary typed session record for
  that runtime
- **AND** the ready startup result includes the stable `session_id`
- **AND** the resulting session links back to the source resolution when the
  startup originated from a resolution-backed flow

#### Scenario: Startup fails before ready runtime attach

- **GIVEN** a local shell starts a supported platform-tunnel mode through the
  control plane
- **WHEN** startup fails during permission acquisition, route validation, host
  bring-up, or runtime attach
- **THEN** the control plane does not leave behind a misleading active session
  for that failed startup attempt
- **AND** the failure remains visible through the typed startup result and
  ordinary diagnostics or event surfaces
