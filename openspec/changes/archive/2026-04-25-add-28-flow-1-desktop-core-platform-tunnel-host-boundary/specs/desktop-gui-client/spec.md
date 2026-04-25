## ADDED Requirements
### Requirement: Desktop GUI remains a typed consumer of packaged desktop tunnel startup

The system SHALL keep the desktop GUI shell as a typed consumer of packaged-host
desktop tunnel startup rather than the owner of native desktop tunnel
primitives.

#### Scenario: Desktop GUI renders system-tunnel workflow without owning native tunnel APIs

- **GIVEN** a production desktop package whose bundled host reports one
  documented system-tunnel mode
- **WHEN** the operator inspects or starts that mode from the desktop GUI
- **THEN** the UI renders capability, execution-plan choice, and typed startup
  result state from the packaged host
- **AND** it does not implement its own direct driver, route, or privileged
  helper lifecycle

### Requirement: Desktop GUI keeps tunnel UX adapter-driven rather than OS-API-driven

The system SHALL keep system-tunnel UX in the desktop shell tied to
host-reported mode metadata and typed startup results instead of one OS
adapter's API naming.

#### Scenario: Future desktop system-tunnel mode reuses the shell role

- **GIVEN** a future packaged desktop host that reports a different native
  system-tunnel adapter from the first shipped desktop mode
- **WHEN** the desktop GUI renders that later mode
- **THEN** the shell keeps the same typed consumer role for capability,
  execution-plan, and startup state
- **AND** it does not require a second UI architecture just because the native
  adapter is different
