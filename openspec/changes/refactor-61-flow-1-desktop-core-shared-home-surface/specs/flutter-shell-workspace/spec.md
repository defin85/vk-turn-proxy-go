## ADDED Requirements

### Requirement: Shared shell workspace owns platform-neutral workflow bodies

The system SHALL keep reusable workflow-body surfaces in the shared shell
workspace when those surfaces do not depend on platform navigation chrome,
plugins, or runtime ownership.

#### Scenario: Desktop and mobile reuse one Home workflow body

- **GIVEN** desktop and mobile both need the same product-facing `Home`
  workflow body
- **WHEN** that body only needs typed shell state, copy, and user-intent
  callbacks
- **THEN** it lives in `packages/flutter_shell_core`
- **AND** both shells consume that shared body instead of maintaining parallel
  app-local compositions

#### Scenario: Platform shell chrome stays app-local around a shared body

- **GIVEN** a workflow surface still needs desktop left-pad routing, inspector
  ownership, mobile rail or bottom navigation, browser/share adapters, or host
  supervision
- **WHEN** the repository assigns ownership for those capabilities
- **THEN** the desktop or mobile app package keeps that shell chrome locally
- **AND** the shared shell core stays limited to the platform-neutral body
  surface rather than forcing one platform's page scaffold onto the other
