## ADDED Requirements
### Requirement: Mobile shell chooses the documented challenge surface per typed challenge mode

The system SHALL let the mobile shell choose between system-browser handoff and an owned in-app WebView challenge surface from typed challenge metadata instead of provider-specific UI heuristics.

#### Scenario: Challenge requires owned in-app web session

- **GIVEN** a mobile session whose active challenge advertises an owned in-app WebView continuation mode
- **WHEN** the operator continues that challenge from the mobile GUI
- **THEN** the mobile shell presents the documented in-app challenge surface instead of launching the system browser
- **AND** it continues to render typed session and challenge updates through the same host bridge contract

#### Scenario: Challenge stays on system-browser handoff

- **GIVEN** a mobile session whose active challenge does not advertise owned in-app WebView continuation
- **WHEN** the operator continues that challenge from the mobile GUI
- **THEN** the mobile shell uses the documented system-browser handoff path
- **AND** it does not silently substitute an embedded web surface
