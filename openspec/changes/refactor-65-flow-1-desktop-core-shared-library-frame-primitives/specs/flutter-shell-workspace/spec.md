## ADDED Requirements

### Requirement: Shared shell core owns workflow library and frame primitives

The system SHALL keep common workflow library and frame primitives in
`packages/flutter_shell_core` so desktop and mobile shells reuse the same body-
level list and section-frame building blocks while keeping shell-owned page
scaffolds app-local.

#### Scenario: Desktop and mobile consume shared library primitives

- **GIVEN** desktop and mobile both need saved-profile lists, reusable
  managed-provider lists, and equivalent empty or hint states
- **WHEN** the repository assigns ownership for those body-level primitives
- **THEN** `packages/flutter_shell_core` provides the shared list and frame
  surfaces for those workflows
- **AND** app packages pass shell-local actions and navigation callbacks into
  those shared primitives instead of forking the whole surface

#### Scenario: Shell-owned scaffolds remain app-local

- **GIVEN** desktop uses a left pad plus dominant canvas and mobile uses
  destination pages, rails, and sheets
- **WHEN** they render shared workflow library and frame primitives
- **THEN** page headers, toolbars, inspectors, navigation bars, and route
  wrappers remain app-local
- **AND** the shared shell core stays body-level and platform-neutral
