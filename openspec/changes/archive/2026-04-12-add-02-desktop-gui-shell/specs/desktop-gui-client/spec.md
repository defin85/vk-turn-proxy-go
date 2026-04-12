## ADDED Requirements
### Requirement: Desktop GUI shell manages local profiles and sessions

The system SHALL provide a desktop GUI shell that manages profiles and sessions through the local client control plane.

#### Scenario: Operator starts a profile from the desktop GUI

- **GIVEN** a desktop installation with a compatible local host
- **WHEN** the operator starts a saved profile from the desktop GUI
- **THEN** the GUI requests session startup through the control plane
- **AND** it renders typed state transitions for that session without requiring terminal interaction

#### Scenario: Operator inspects session diagnostics from the desktop GUI

- **GIVEN** a running or failed session
- **WHEN** the operator opens diagnostics in the desktop GUI
- **THEN** the GUI can show or export the host-provided diagnostics bundle for that session

### Requirement: Desktop GUI shell supervises a compatible local host

The system SHALL ensure that the desktop GUI interacts only with a compatible local host process.

#### Scenario: Compatible host is not running

- **GIVEN** the desktop GUI starts and no compatible local host is available
- **WHEN** the GUI initializes runtime management
- **THEN** it starts or prompts for the local host explicitly
- **AND** it does not attempt to manage sessions through an unavailable host

#### Scenario: Host version is incompatible

- **GIVEN** the desktop GUI finds a local host with an incompatible control-plane version
- **WHEN** compatibility negotiation runs
- **THEN** the GUI reports the incompatibility explicitly
- **AND** it blocks session management until a compatible host is available

### Requirement: Desktop GUI shell supports browser-oriented challenge handoff

The system SHALL let the desktop GUI coordinate provider challenges without embedding provider behavior into the UI shell.

#### Scenario: Session requires browser challenge continuation

- **GIVEN** a desktop session that reaches a provider challenge state
- **WHEN** the operator chooses to continue from the GUI
- **THEN** the GUI initiates the documented browser handoff flow through the host
- **AND** the resulting challenge completion or cancellation is reflected back through typed session events
