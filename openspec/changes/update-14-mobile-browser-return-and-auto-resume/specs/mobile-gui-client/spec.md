## ADDED Requirements
### Requirement: Mobile browser handoff may auto-resume once on documented app return

The system SHALL allow the mobile shell to issue at most one best-effort automatic challenge continue per active eligible challenge when the challenge metadata declares an app-return-compatible handoff mode and the app receives a matching documented return signal for that challenge.

#### Scenario: App return triggers one automatic continue attempt

- **GIVEN** a mobile session with an active provider challenge that advertises app-return-assisted continuation
- **AND** the challenge metadata reports the supported return-signal kind for that challenge
- **AND** the operator completes the browser step and returns to the app through the documented return path or supported foreground-resume path
- **WHEN** the mobile shell processes that matching return signal while the same challenge is still active
- **THEN** it issues one automatic continue request through the mobile host bridge
- **AND** it renders the resulting typed session or challenge updates without requiring an immediate second tap by default

#### Scenario: Repeated lifecycle noise does not loop automatic continue

- **GIVEN** a mobile session with an active provider challenge that already triggered its one automatic continue attempt
- **WHEN** the app receives repeated foreground resumes or duplicate return callbacks before the host emits a new eligible challenge
- **THEN** the mobile shell does not issue a second automatic continue for that challenge
- **AND** it waits for typed host updates or explicit operator action

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

### Requirement: Mobile browser handoff keeps browser-launch and post-browser completion semantics distinct

The system SHALL keep the action that opens or re-opens the browser handoff distinct from any post-browser confirmation action so operators can tell whether the app will launch the browser or ask the host to continue.

#### Scenario: Challenge surface distinguishes launch from completion

- **GIVEN** a mobile session with an active provider challenge and visible browser handoff controls
- **WHEN** the shell renders that challenge before or after the browser step
- **THEN** the browser-launch control is presented as a launch or re-open action
- **AND** any manual fallback continuation control is presented as post-browser completion rather than another browser-launch action
- **AND** automatic continuation, when supported, does not relabel browser launch as proof that provider resolution already succeeded
