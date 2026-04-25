## ADDED Requirements

### Requirement: Shared shell core owns a shared managed-provider workflow surface

The system SHALL keep the body-level reusable managed-provider workflow in
`packages/flutter_shell_core` so desktop and mobile shells reuse one shared
managed-provider editing surface while keeping root-level provider navigation
and non-shared entry semantics app-local.

#### Scenario: Desktop and mobile consume one shared managed-provider editor

- **GIVEN** desktop and mobile both render descriptor-driven reusable provider
  record editing with save, delete, and apply-to-profile actions
- **WHEN** the repository assigns ownership for that workflow body
- **THEN** `packages/flutter_shell_core` provides one platform-neutral shared
  managed-provider workflow surface and its typed data contract
- **AND** desktop and mobile import the same shared editor implementation

#### Scenario: Template and preset wrappers stay app-local

- **GIVEN** mobile exposes template-specific provider flows and desktop exposes
  shell-owned preset and provider-family entry surfaces
- **WHEN** those apps embed the shared managed-provider workflow surface
- **THEN** template roots, preset bootstrap, and route wrappers remain
  app-local
- **AND** the shared shell core does not treat those app-owned wrappers as part
  of the mandatory shared editor contract
