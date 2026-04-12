## ADDED Requirements
### Requirement: Client control plane manages profiles and sessions through a stable local API

The system SHALL expose a stable local control plane for profile management and session lifecycle operations.

#### Scenario: GUI starts a session through the control plane

- **GIVEN** a stored profile with valid runtime parameters
- **WHEN** a local client shell asks the control plane to start a session
- **THEN** the control plane creates a typed session record
- **AND** it returns a stable session identifier instead of requiring the caller to parse CLI output

#### Scenario: GUI stops a running session through the control plane

- **GIVEN** a running local session
- **WHEN** a local client shell asks the control plane to stop it
- **THEN** the control plane terminates the corresponding runtime attempt
- **AND** it reports the terminal state through the same typed API

### Requirement: Client control plane streams typed runtime events

The system SHALL stream typed local events for session lifecycle, readiness, retries, failures, and provider challenges.

#### Scenario: Provider challenge is surfaced to the GUI

- **GIVEN** a session whose provider resolution requires operator action
- **WHEN** the runtime reaches that challenge state
- **THEN** the control plane emits a typed challenge event with a stable challenge identifier
- **AND** the GUI can continue or cancel the challenge without parsing human log text

#### Scenario: Runtime reaches ready state

- **GIVEN** a session that completes provider resolution and transport startup successfully
- **WHEN** the runtime becomes ready
- **THEN** the control plane emits a typed ready event for that session
- **AND** readiness is associated with the session identifier exposed by the control plane

### Requirement: Client control plane exposes capability and version negotiation

The system SHALL expose the local host capabilities and a versioned contract so GUI shells can reject incompatible hosts explicitly.

#### Scenario: GUI detects incompatible local host

- **GIVEN** a local GUI shell and a host implementation that do not share a compatible control-plane version
- **WHEN** the GUI connects to the host
- **THEN** the host reports the incompatibility explicitly
- **AND** the GUI does not attempt to start or manage sessions through an undefined API
