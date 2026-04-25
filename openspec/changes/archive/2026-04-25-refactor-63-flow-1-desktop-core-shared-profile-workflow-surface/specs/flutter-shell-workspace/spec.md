## ADDED Requirements

### Requirement: Shared shell core owns a shared profile workflow surface

The system SHALL keep the body-level saved-profile workflow in
`packages/flutter_shell_core` so desktop and mobile shells reuse one shared
profile editing surface while keeping shell-owned navigation and platform
adapters app-local.

#### Scenario: Desktop and mobile consume one shared profile workflow body

- **GIVEN** desktop and mobile both render saved-profile editing, managed
  versus custom provider mode switching, and portable-profile draft state
- **WHEN** the repository assigns ownership for that workflow body
- **THEN** `packages/flutter_shell_core` provides one platform-neutral shared
  profile workflow surface and its typed data contract
- **AND** desktop and mobile import the same shared implementation instead of
  keeping separate profile editor bodies

#### Scenario: App-local wrappers keep shell and platform ownership

- **GIVEN** desktop and mobile expose different navigation, transfer
  affordances, and shell-owned profile entry flows
- **WHEN** they embed the shared profile workflow surface
- **THEN** page navigation, left-pad routing, current-profile targeting, and
  share, file, QR, or browser adapters remain in app-local code
- **AND** the shared shell core does not take ownership of platform plugins or
  shell route state
