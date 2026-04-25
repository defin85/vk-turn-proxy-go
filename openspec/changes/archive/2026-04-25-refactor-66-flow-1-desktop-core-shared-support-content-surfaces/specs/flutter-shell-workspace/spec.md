## ADDED Requirements

### Requirement: Shared shell core owns support content surfaces

The system SHALL keep body-level activity and diagnostics content in
`packages/flutter_shell_core` so desktop inspectors and mobile support
workflows reuse the same support-content surfaces while keeping support shell
ownership app-local.

#### Scenario: Desktop and mobile consume one shared support-content layer

- **GIVEN** desktop and mobile both need activity, session, diagnostics
  overview, and event content for the same local control-plane state
- **WHEN** the repository assigns ownership for those support bodies
- **THEN** `packages/flutter_shell_core` provides the shared support-content
  surfaces and their typed data contract
- **AND** desktop and mobile embed that shared content instead of keeping
  separate body implementations

#### Scenario: Support wrappers remain app-local

- **GIVEN** desktop uses inspectors and mobile uses a dedicated support
  workflow with its own compact and wide wrappers
- **WHEN** those apps adopt the shared support-content surfaces
- **THEN** inspector chrome, support toolbars, route wrappers, and
  mobile-specific embedded-browser controls remain app-local
- **AND** the shared shell core does not take ownership of support route state

