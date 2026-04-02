## ADDED Requirements

### Requirement: Generic TURN provider resolves static credentials

The system SHALL provide a deterministic `generic-turn` provider that resolves static TURN credentials from a provider link.

#### Scenario: Resolve a valid static TURN link

- **GIVEN** a link in the form `generic-turn://<username>:<password>@<host>:<port>`
- **WHEN** the operator resolves it through probe or tunnel-client
- **THEN** the provider returns the supplied username and password
- **AND** the normalized TURN address is `host:port`
- **AND** no live provider signaling is performed

#### Scenario: Reject a malformed static TURN link

- **GIVEN** a `generic-turn` link with a missing username, password, host, or port
- **WHEN** the operator resolves it
- **THEN** the provider fails before transport startup
- **AND** the error explicitly identifies the malformed static credential input

### Requirement: Generic TURN provider emits sanitized probe artifacts

The system SHALL emit sanitized probe artifacts for the `generic-turn` provider so local runs can be debugged without leaking secrets.

#### Scenario: Successful static provider artifact capture

- **GIVEN** a successful `generic-turn` resolution
- **WHEN** the probe persists its artifact
- **THEN** the artifact records the normalized outcome
- **AND** the raw username and password are redacted before persistence
