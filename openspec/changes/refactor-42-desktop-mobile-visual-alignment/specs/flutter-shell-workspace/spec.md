## ADDED Requirements

### Requirement: Shared shell workspace owns cross-shell visual primitives

The system SHALL keep reusable cross-shell visual primitives in the shared
shell workspace when they do not depend on platform-specific chrome or plugins.

#### Scenario: Desktop and mobile use one shared visual primitive

- **GIVEN** desktop and mobile need the same product token or component
  treatment such as status tones, action emphasis, or surface styling
- **WHEN** the repository assigns ownership for that primitive
- **THEN** it lives in `packages/flutter_shell_core`
- **AND** both shells consume the same shared definition instead of drifting
  into parallel copies

#### Scenario: Platform-specific chrome stays app-local

- **GIVEN** a visual wrapper depends on desktop windowing, keyboard affordances,
  or mobile-native presentation
- **WHEN** the repository assigns ownership for that wrapper
- **THEN** the desktop or mobile app package keeps it locally
- **AND** the shared shell core does not force one platform's layout idioms
  onto the other
