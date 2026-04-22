## ADDED Requirements

### Requirement: Shared shell core owns a shared routing content surface

The system SHALL keep the body-level routing workflow in
`packages/flutter_shell_core` so desktop and mobile shells reuse one shared
routing-content surface while keeping shell-owned wrappers and selectors
app-local.

#### Scenario: Desktop and mobile consume one shared routing body

- **GIVEN** desktop and mobile both expose routing parameters, mode controls,
  and platform-tunnel status for the current profile
- **WHEN** the repository assigns ownership for that routing body
- **THEN** `packages/flutter_shell_core` provides one platform-neutral shared
  routing-content surface and its typed data contract
- **AND** desktop and mobile embed that shared body instead of maintaining
  separate routing workflow bodies

#### Scenario: Shell-owned selectors and wrappers remain local

- **GIVEN** mobile and desktop still expose some routing controls through
  shell-local selectors, sheets, or route actions
- **WHEN** they adopt the shared routing-content surface
- **THEN** those selectors and wrappers remain app-local
- **AND** the shared shell core does not take ownership of host supervision,
  platform tunnel startup policy, or shell navigation state
