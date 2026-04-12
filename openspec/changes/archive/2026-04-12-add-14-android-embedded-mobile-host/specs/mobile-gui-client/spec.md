## MODIFIED Requirements
### Requirement: Mobile GUI shell manages local profiles and sessions through an embedded host

The system SHALL provide a mobile GUI shell that manages profiles and sessions through a mobile host bridge instead of terminal-oriented CLI execution.
Production Android packages SHALL satisfy that bridge through a packaged app-owned host, while external bridge configuration remains limited to explicit development workflows.

#### Scenario: Production Android package boots with a packaged host

- **GIVEN** an Android production installation that includes the packaged embedded host
- **WHEN** the operator launches the mobile GUI shell
- **THEN** the app negotiates with the packaged host through the mobile host bridge
- **AND** it does not require an external `clientd`, companion app, or manual bridge configuration to reach runtime-ready state

#### Scenario: Development bridge override is explicit

- **GIVEN** an Android development build with an explicit bridge override
- **WHEN** the mobile GUI shell initializes
- **THEN** it may connect to the documented development bridge path instead of the packaged host
- **AND** that override does not redefine the default production delivery model
