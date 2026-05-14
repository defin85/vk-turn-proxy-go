## MODIFIED Requirements
### Requirement: Linux privileged helpers receive only ephemeral execution inputs

The system SHALL keep provider resolution, browser continuation,
transport-profile persistence, execution-plan selection, execution-lease
materialization, and ordinary control-plane state outside the privileged Linux
helper boundary. A privileged Linux helper SHALL receive only structured,
attempt-scoped execution inputs needed for one native `linux_tun` startup or
cleanup operation.

#### Scenario: Linux helper receives one startup attempt

- **GIVEN** a packaged Linux desktop host starting one documented `linux_tun`
  startup attempt
- **WHEN** the host invokes the privileged helper
- **THEN** the helper receives only the protocol/schema version, helper
  compatibility identity, startup attempt id, attempt nonce, selected
  execution plan identity, materialized ephemeral execution lease, and
  host-owned route or DNS policy directives for that attempt
- **AND** the helper does not own provider resolution, transport-profile store
  access, browser continuation, or shell persistence state

#### Scenario: Linux helper rejects non-ephemeral inputs

- **GIVEN** a packaged Linux desktop host invokes the privileged helper
- **WHEN** the helper payload contains provider identifiers, provider links,
  profile-store paths, browser settings, shell persistence paths, arbitrary
  command fields, stale or duplicate attempt identities, oversized payloads,
  or unknown schema fields
- **THEN** the helper rejects the payload fail-closed
- **AND** the unprivileged host reports a typed platform-tunnel startup
  failure instead of continuing with guessed privileged behavior

#### Scenario: Linux helper does not become a public control-plane surface

- **GIVEN** the desktop GUI is connected to the local control plane
- **WHEN** it starts, stops, or inspects a Linux platform tunnel
- **THEN** it communicates only with the canonical local `clientd` control
  plane
- **AND** it never calls the privileged helper directly or depends on
  helper-specific URLs, sockets, prompts, or stdout parsing

## ADDED Requirements
### Requirement: Linux desktop host remains the canonical owner of helper lifecycle

The packaged Linux desktop host SHALL own helper invocation, helper result
translation, and helper cleanup while keeping the Flutter shell a typed
consumer of platform-tunnel state.

#### Scenario: Helper permission is denied

- **GIVEN** the unprivileged Linux local host is reachable
- **WHEN** the operator denies or cannot complete the helper privilege prompt
- **THEN** the host reports a typed platform-tunnel startup failure through the
  canonical control-plane result
- **AND** the Flutter shell remains connected to the same local host

#### Scenario: Helper fails after partial native state

- **GIVEN** the privileged helper has created partial Linux-native tunnel state
- **WHEN** the helper exits unexpectedly or reports a startup failure
- **THEN** the packaged Linux desktop host remains responsible for cleanup
  through the documented helper lifecycle
- **AND** the shell does not need helper-specific cleanup logic

#### Scenario: Active helper remains attempt-scoped

- **GIVEN** a packaged Linux desktop host starts `linux_tun`
- **AND** the supported helper implementation owns the active TUN handle or
  WireGuard TURN runtime attach
- **WHEN** the tunnel remains active after startup readiness
- **THEN** the helper remains associated with exactly one host-owned active
  attempt
- **AND** stop, cleanup, helper crash, and stale native-state reconciliation
  are translated by the host into typed platform-tunnel state
- **AND** the helper does not expose a second public local-control API
