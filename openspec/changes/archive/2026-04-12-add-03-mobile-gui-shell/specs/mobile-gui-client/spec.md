## ADDED Requirements
### Requirement: Mobile GUI shell manages local profiles and sessions through an embedded host

The system SHALL provide a mobile GUI shell that manages profiles and sessions through a mobile host bridge instead of terminal-oriented CLI execution.

#### Scenario: Operator starts a profile from the mobile GUI

- **GIVEN** a mobile installation with a compatible embedded host
- **WHEN** the operator starts a saved profile from the mobile GUI
- **THEN** the GUI requests session startup through the mobile host bridge
- **AND** it renders typed state transitions without requiring shell access

#### Scenario: Mobile host is incompatible

- **GIVEN** a mobile GUI shell and an embedded host bridge that does not satisfy the expected control-plane version
- **WHEN** the app initializes runtime management
- **THEN** the app reports the incompatibility explicitly
- **AND** it does not attempt to start or resume sessions through the incompatible host

### Requirement: Mobile GUI shell uses platform-native challenge handoff and secure storage

The system SHALL use platform-native secure storage and browser-oriented challenge handoff for mobile profile and session management.

#### Scenario: Session requires provider challenge continuation

- **GIVEN** a mobile session that reaches a provider challenge state
- **WHEN** the operator chooses to continue from the mobile GUI
- **THEN** the app initiates the documented mobile browser handoff flow
- **AND** challenge completion or cancellation is reflected back through typed session events

#### Scenario: Profile stores runtime secrets

- **GIVEN** a mobile profile that includes provider or runtime secrets
- **WHEN** the app persists that profile locally
- **THEN** it stores those secrets through platform-native secure storage
- **AND** it does not require plaintext secret storage in general app preferences

### Requirement: First mobile GUI slice does not imply system tunnel support

The system SHALL keep the first mobile GUI slice distinct from future system-wide traffic capture support.

#### Scenario: Mobile app lacks platform tunnel integration

- **GIVEN** the first mobile GUI slice is installed without later platform tunnel capabilities
- **WHEN** the operator inspects platform support in the app
- **THEN** the app reports that system tunnel support is not yet available for that slice
- **AND** it does not silently claim device-wide traffic capture
