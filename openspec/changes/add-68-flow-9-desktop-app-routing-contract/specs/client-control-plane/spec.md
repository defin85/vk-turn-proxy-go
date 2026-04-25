## ADDED Requirements

### Requirement: Client control plane negotiates desktop app-routing selectors explicitly

The system SHALL expose desktop application-routing support through typed
capability metadata and startup inputs instead of reusing Android package lists
or inferring support from platform-tunnel mode names.

#### Scenario: Desktop host lacks app-routing capability

- **GIVEN** a shell connects to a desktop host that supports a platform tunnel
  mode but does not advertise desktop app-routing enforcement for that mode
- **WHEN** the shell reads control-plane capability metadata
- **THEN** the metadata keeps desktop app-routing unavailable for that mode
- **AND** the shell fails closed or suppresses app-routing controls instead of
  sending app selectors optimistically

#### Scenario: Shell starts a desktop tunnel with app selectors

- **GIVEN** a desktop host advertises app-routing support for one platform
  tunnel mode
- **AND** the shell has selected one supported app-routing policy and one or
  more host-reported desktop app identities where required
- **WHEN** the shell starts that platform tunnel through the local control
  plane
- **THEN** the startup request carries typed desktop app-routing selector data
  separate from Android package-routing fields
- **AND** the host validates those selectors before reporting readiness

#### Scenario: Unknown desktop app selector is rejected

- **GIVEN** a shell submits a desktop app-routing selector that the host did not
  report or can no longer resolve
- **WHEN** startup validation runs
- **THEN** the host returns a typed startup failure
- **AND** it does not silently widen the request to all-app or IP-only routing
