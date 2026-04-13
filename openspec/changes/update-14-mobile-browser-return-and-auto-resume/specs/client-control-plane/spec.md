## ADDED Requirements
### Requirement: Client control plane exposes typed challenge completion and browser-return metadata

The system SHALL expose machine-readable challenge completion and browser-return metadata so shells can distinguish manual confirmation, app-return-assisted continuation, and host-observed browser continuation without parsing provider text.
For app-return-assisted continuation, the challenge record SHALL also declare the supported return-signal kinds for that challenge and whether one automatic continue attempt is allowed.

#### Scenario: Challenge event advertises app-return-assisted continuation

- **GIVEN** a session whose provider challenge can resume through a documented mobile app-return path
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record includes a stable challenge identifier, a typed completion mode for app-return-assisted continuation, and typed return-signal metadata for that challenge
- **AND** the shell can determine that one automatic continue attempt is allowed without inferring behavior from prompt text or generic lifecycle heuristics alone

#### Scenario: Challenge event remains manual-only

- **GIVEN** a session whose provider challenge still requires explicit user confirmation after the browser step
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record keeps the same stable challenge identifier model
- **AND** it explicitly reports manual confirmation semantics instead of implying automatic resume support
