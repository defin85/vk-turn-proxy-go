## MODIFIED Requirements

### Requirement: Owned mobile WebView continuation preserves app-owned session boundaries

The system SHALL keep embedded continuation state inside app-managed WebView
storage, must not import session state from the user's external browser
profile, and SHALL expose an explicit reset path that clears only the
app-owned browser session state required for owned-browser continuation.

#### Scenario: Embedded continuation keeps browser state inside the app sandbox

- **GIVEN** a mobile challenge that runs through an owned in-app WebView
- **WHEN** provider continuation needs cookies, storage, or other
  browser-backed state from that flow
- **THEN** the runtime uses the app-owned embedded session state for that
  continuation
- **AND** it does not read cookies or profile data from the user's regular
  browser installation

#### Scenario: Ambient system credential hints do not redefine the app-owned boundary

- **GIVEN** Android autofill or password-manager suggestions appear while the
  operator is inside an owned in-app WebView challenge
- **AND** the product has not explicitly enabled the documented intentional
  system credential integration path for that flow
- **WHEN** the operator sees, uses, or dismisses those suggestions
- **THEN** the shell still treats owned-browser continuation state as app-owned
  embedded browser state only
- **AND** it does not relabel ambient system credential hints as part of the
  app-owned remembered sign-in contract

#### Scenario: Operator explicitly forgets embedded sign-in

- **GIVEN** an approved mobile owned-browser flow remembered app-owned browser
  state from an earlier embedded VK session
- **WHEN** the operator invokes the explicit reset or forget action for that
  embedded browser state
- **THEN** the shell clears the app-owned browser cookies and browser storage
  required for that remembered sign-in session
- **AND** it does not wipe saved profiles, managed providers, drafts,
  diagnostics, or unrelated shell preferences
