## MODIFIED Requirements

### Requirement: Client control plane exposes typed challenge completion and browser-return metadata

The system SHALL expose machine-readable challenge completion, browser-return,
and owned-browser continuation metadata so shells can distinguish manual
confirmation, app-return-assisted continuation, and app-owned
browser-observed continuation without parsing provider text.
For app-return-assisted continuation, the challenge record SHALL also declare
the supported return-signal kinds for that challenge and whether one automatic
continue attempt is allowed.
For app-owned browser-observed continuation, the challenge record SHALL also
declare owned-browser cookie-scope metadata, and the continue contract SHALL
accept same-session embedded cookies and browser-observed request evidence from
that same owned-browser session.

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

#### Scenario: Challenge event advertises owned-browser-observed continuation

- **GIVEN** a session whose approved mobile provider challenge can continue inside one app-owned browser session
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record includes a stable challenge identifier, the `owned_browser_observed` completion mode, and owned-browser metadata with the cookie URL scope for that session
- **AND** the shell can open the approved app-owned browser path without inferring cookie scope from provider prompt text alone

#### Scenario: Owned-browser continuation accepts same-session observed evidence

- **GIVEN** an approved mobile provider challenge whose committed continuation contour depends on same-session browser-observed evidence
- **WHEN** the shell continues that challenge with a typed owned-browser payload captured from the same embedded session
- **THEN** the host accepts embedded cookies and browser-observed request evidence from that session through the control-plane contract
- **AND** approval does not depend on the challenge also exposing browser-owned replay requests
