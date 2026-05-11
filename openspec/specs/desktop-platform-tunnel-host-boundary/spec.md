# desktop-platform-tunnel-host-boundary Specification

## Purpose
Define the ownership boundary between the desktop Flutter shell, packaged
desktop host, and Go control plane for platform-tunnel delivery so native
tunnel primitives remain host-owned and typed state remains control-plane-owned.
## Requirements
### Requirement: Packaged desktop system-tunnel delivery keeps shell, host, and control plane ownership separate

The system SHALL deliver repo-owned desktop platform-tunnel paths with an
explicit ownership split across the desktop Flutter shell, the packaged desktop
host, and the Go control plane.

#### Scenario: Operator starts a desktop system-tunnel mode from the GUI

- **GIVEN** a packaged desktop build that includes one documented system-tunnel
  mode
- **WHEN** the operator starts that mode from the desktop GUI
- **THEN** the GUI acts as a typed consumer of capability, execution-plan, and
  startup result state
- **AND** the UI does not directly own OS tunnel primitive lifecycle, route
  manipulation, or privileged cleanup

### Requirement: Packaged desktop host owns native tunnel primitives

The system SHALL keep driver, extension, route, DNS, and OS packet-capture
primitives inside the packaged desktop host boundary.

#### Scenario: Packaged desktop host applies native tunnel policy

- **GIVEN** a packaged desktop host starting one documented system-tunnel mode
- **WHEN** startup acquires the native tunnel primitive and applies route or DNS
  policy
- **THEN** those OS-native operations are owned by the packaged desktop host
- **AND** the repository does not require Flutter UI code or shared Go transport
  packages to manipulate those native primitives directly

### Requirement: Go control plane remains the canonical orchestrator across desktop adapters

The system SHALL keep typed startup orchestration, execution-plan ownership, and
runtime attach under the Go control plane even when desktop tunnel bring-up uses
OS-specific helper code.

#### Scenario: Native desktop adapter returns startup state to the packaged host

- **GIVEN** a packaged desktop host starting a documented system-tunnel mode
- **WHEN** the OS-specific desktop adapter completes or fails a startup stage
- **THEN** the Go control plane remains the canonical source of typed startup
  result state
- **AND** the packaged build does not expose a second desktop-only tunnel API to
  the shell

### Requirement: Shared desktop ownership boundaries stay reusable while native adapters remain OS-specific

The system SHALL keep the desktop host boundary reusable at the ownership level
without leaking one OS adapter's API names into shared Flutter or Go contracts.

#### Scenario: Later desktop mode uses a different native adapter

- **GIVEN** a future packaged desktop host that uses a different native adapter
  such as `linux_tun` or desktop `apple_network_extension`
- **WHEN** the repository reuses the packaged ownership split from this change
- **THEN** the desktop shell still acts as a typed consumer and the Go control
  plane still acts as the canonical orchestrator
- **AND** only the packaged native adapter implementation changes
- **AND** the shared boundary does not require Windows-specific API types to be
  present in Flutter or Go code

### Requirement: Packaged Linux desktop hosts may use a privileged helper without splitting the desktop host boundary

The system SHALL allow a packaged Linux desktop host to reach `linux_tun`
through a repo-owned privileged helper while preserving one typed desktop host
boundary.

#### Scenario: Linux packaged host launches a helper for native tunnel work

- **GIVEN** a packaged Linux desktop host that implements one documented
  `linux_tun` path
- **WHEN** startup needs privileged TUN, route, DNS, or cleanup work
- **THEN** the packaged Linux desktop host may reach a repo-owned privileged
  helper
- **AND** the Flutter shell still acts only as a typed consumer of capability,
  execution-plan, and startup result state
- **AND** the helper does not become a second public API surface for the shell

### Requirement: Linux privileged helpers receive only ephemeral execution inputs

The system SHALL keep provider resolution, transport-profile materialization,
and ordinary control-plane state outside the privileged Linux helper boundary.

#### Scenario: Linux helper receives one startup attempt

- **GIVEN** a packaged Linux desktop host starting one documented `linux_tun`
  startup attempt
- **WHEN** the host invokes the privileged helper
- **THEN** the helper receives only the ephemeral execution lease and
  host-owned route or policy directives for that attempt
- **AND** the helper does not own provider resolution, transport-profile store
  access, or shell persistence state
