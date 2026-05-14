## MODIFIED Requirements
### Requirement: Packaged desktop system-tunnel delivery keeps shell, host, and control plane ownership separate

The system SHALL deliver repo-owned desktop platform-tunnel paths with an
explicit ownership split across the desktop Flutter shell, the packaged desktop
host, and the Go control plane. That ownership split SHALL remain true whether
the packaged host is reached as a loopback sidecar process or as a
process-local embedded backend.

#### Scenario: Operator starts a desktop system-tunnel mode from the GUI

- **GIVEN** a packaged desktop build that includes one documented system-tunnel
  mode
- **WHEN** the operator starts that mode from the desktop GUI
- **THEN** the GUI acts as a typed consumer of capability, execution-plan, and
  startup result state
- **AND** the UI does not directly own OS tunnel primitive lifecycle, route
  manipulation, or privileged cleanup

#### Scenario: Embedded backend starts a desktop system-tunnel mode

- **GIVEN** a packaged desktop build uses a process-local embedded host backend
- **WHEN** the operator starts a documented desktop system-tunnel mode
- **THEN** the embedded backend preserves the same host-owned native adapter
  and Go control-plane orchestration boundary as the sidecar host
- **AND** it does not expose a second desktop-only tunnel API to the shell
