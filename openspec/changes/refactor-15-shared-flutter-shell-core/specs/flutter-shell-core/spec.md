## ADDED Requirements
### Requirement: Flutter shells share one platform-neutral shell core

The system SHALL provide one shared Flutter shell core package for platform-neutral code reused by the desktop and mobile GUI shells.

#### Scenario: Desktop and mobile shells use the same control-plane-facing package

- **GIVEN** the desktop and mobile Flutter shell packages
- **WHEN** they need typed control-plane models, control-plane HTTP client behavior, profile draft shaping, or shared build identity helpers
- **THEN** they import that logic from one shared Flutter shell core package
- **AND** they do not keep separate copy-pasted implementations of the same platform-neutral code in each app package

#### Scenario: Shared shell UI primitives stay reusable across shells

- **GIVEN** a shell UI primitive that only depends on Flutter and shared shell abstractions
- **WHEN** both desktop and mobile shells need that primitive
- **THEN** the primitive lives in the shared Flutter shell core package
- **AND** both shells can consume it without importing each other's runtime adapters

### Requirement: Platform-specific host wiring remains outside the shared shell core

The system SHALL keep platform-specific host bootstrap, persistence, and lifecycle integrations outside the shared Flutter shell core package.

#### Scenario: Desktop shell keeps sidecar supervision local

- **GIVEN** the desktop GUI shell
- **WHEN** it discovers, launches, or supervises a compatible `clientd` sidecar and persists desktop-local shell state
- **THEN** that logic remains in desktop-specific code
- **AND** the shared shell core does not take ownership of desktop sidecar or desktop persistence concerns

#### Scenario: Mobile shell keeps native bridge and secure storage local

- **GIVEN** the mobile GUI shell
- **WHEN** it resolves a native host bridge, persists secrets through platform-native secure storage, or reacts to app lifecycle and browser handoff events
- **THEN** that logic remains in mobile-specific code
- **AND** the shared shell core does not take ownership of mobile bridge, secure storage, or lifecycle concerns

### Requirement: Shared shell packages resolve through one repo-owned package topology

The system SHALL wire the shared shell core and shell app packages through one repo-owned multi-package package topology.

#### Scenario: Shared package changes validate against both shells

- **GIVEN** a repository change that updates the shared Flutter shell core package
- **WHEN** shell dependencies are resolved and validation runs
- **THEN** the repository resolves the shared shell package and both shell app packages through one repo-owned package topology
- **AND** desktop and mobile shell validation can run against the same extracted shared code without manual copy steps
