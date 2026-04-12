## ADDED Requirements
### Requirement: Client control plane exposes typed challenge completion metadata

The system SHALL expose machine-readable challenge completion metadata so shells can distinguish manual confirmation, app-return-assisted continuation, and host-observed browser continuation without parsing provider text.

#### Scenario: Challenge event advertises app-return-assisted continuation

- **GIVEN** a session whose provider challenge can resume through a documented mobile app-return path
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record includes a stable challenge identifier and a typed completion mode for app-return-assisted continuation
- **AND** the shell can determine that one automatic continue attempt is allowed without inferring behavior from prompt text alone

#### Scenario: Challenge event remains manual-only

- **GIVEN** a session whose provider challenge still requires explicit user confirmation after the browser step
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record keeps the same stable challenge identifier model
- **AND** it explicitly reports manual confirmation semantics instead of implying automatic resume support
