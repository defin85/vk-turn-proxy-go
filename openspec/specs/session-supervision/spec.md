# session-supervision Specification

## Purpose
Define the supervised client session lifecycle contract for shared local listener ownership, worker startup and restart policy, coordinated shutdown, and stage-aware lifecycle failures.
## Requirements
### Requirement: Client sessions are supervised explicitly

The system SHALL supervise client transport workers through an explicit session lifecycle model instead of running one unmanaged transport instance.

#### Scenario: Start a supervised multi-worker session

- **GIVEN** a supported client configuration with a configured connection count
- **WHEN** the client session starts successfully
- **THEN** the session supervisor starts the configured number of transport workers
- **AND** the session reports a single session identity across those workers

#### Scenario: Coordinated shutdown

- **GIVEN** a running supervised client session
- **WHEN** the process is cancelled or the session is asked to stop
- **THEN** listeners, TURN resources, and worker goroutines are closed cleanly
- **AND** the session exits without leaving partially running workers behind

#### Scenario: Worker failure under supervision

- **GIVEN** a running supervised session and a worker transport failure
- **WHEN** the supervisor handles that failure
- **THEN** it applies the documented lifecycle policy for restart or full session failure
- **AND** the resulting error names the lifecycle stage that failed
