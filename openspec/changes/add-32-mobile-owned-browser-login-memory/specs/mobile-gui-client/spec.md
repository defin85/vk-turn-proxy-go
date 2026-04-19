## ADDED Requirements

### Requirement: Mobile shell exposes remembered embedded sign-in reset without full local-state wipe

The system SHALL let the operator clear remembered app-owned browser sign-in
state from the mobile shell through a dedicated embedded sign-in reset action,
without requiring app reinstall or a full local state reset.

#### Scenario: Operator clears remembered embedded sign-in from the mobile shell

- **GIVEN** the mobile shell previously remembered sign-in state for a
  compatible owned-browser continuation flow
- **WHEN** the operator invokes the documented embedded sign-in reset action
- **THEN** the mobile shell clears that app-owned browser session state
- **AND** a later owned-browser challenge starts from signed-out embedded
  browser state
- **AND** saved profiles, selected profile state, and ordinary shell
  preferences remain intact
- **AND** the operator does not need to invoke the broader local-state reset
  action to clear remembered embedded sign-in
