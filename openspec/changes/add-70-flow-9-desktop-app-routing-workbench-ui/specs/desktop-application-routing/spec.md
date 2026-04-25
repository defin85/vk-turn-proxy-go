## ADDED Requirements

### Requirement: Operator-facing desktop app inventory preserves host identity meaning

The system SHALL display desktop app-routing inventory from host-provided
identity metadata so operator choices map back to the same selectors the host
can validate and enforce.

#### Scenario: Shell renders host-owned selector identity

- **GIVEN** a desktop host returns app inventory with stable selector keys,
  display metadata, identity kind, and enforceability state
- **WHEN** the shell renders the app-routing selector UI
- **THEN** each selectable row is backed by the host-owned selector key
- **AND** secondary identity detail is shown from host metadata where available
- **AND** the shell does not synthesize selector keys from labels, translated
  text, or visible file paths

#### Scenario: Host reports an unenforceable app identity

- **GIVEN** the app inventory includes an app identity that the host can display
  but cannot enforce for the current app-routing mode
- **WHEN** the shell renders the app-routing selector UI
- **THEN** that identity is disabled or marked unavailable for selection
- **AND** the unavailable state is derived from host metadata
- **AND** selecting it is not allowed unless the host later reports it as
  enforceable
