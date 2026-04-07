## ADDED Requirements
### Requirement: Mobile browser handoff may auto-resume once on documented app return

The system SHALL allow the mobile shell to issue one best-effort automatic challenge continue when the challenge metadata declares an app-return-compatible handoff mode and the app receives the documented return signal for that session.

#### Scenario: App return triggers one automatic continue attempt

- **GIVEN** a mobile session with an active provider challenge that advertises app-return-assisted continuation
- **AND** the operator completes the browser step and returns to the app through the documented return path or supported foreground-resume path
- **WHEN** the mobile shell processes that return signal
- **THEN** it issues one automatic continue request through the mobile host bridge
- **AND** it renders the resulting typed session or challenge updates without requiring an immediate second tap by default

### Requirement: Mobile browser handoff keeps explicit fallback confirmation

The system SHALL keep explicit post-browser confirmation controls whenever automatic continuation is unavailable, ambiguous, or insufficient to complete provider resolution.

#### Scenario: Automatic continue is not supported for the challenge

- **GIVEN** a mobile session with an active provider challenge that does not advertise app-return-assisted continuation
- **WHEN** the operator returns from the browser flow to the app
- **THEN** the mobile shell keeps an explicit post-browser confirmation action
- **AND** it does not imply that returning to the app alone completed provider resolution

#### Scenario: Automatic continue does not complete the challenge

- **GIVEN** a mobile session whose challenge triggered one automatic continue attempt on app return
- **WHEN** the host remains in `challenge_required` or fails during `provider_resolve`
- **THEN** the mobile shell restores or keeps explicit post-browser completion and cancellation actions
- **AND** the shell reports the typed failure or updated challenge state instead of looping automatic continues
