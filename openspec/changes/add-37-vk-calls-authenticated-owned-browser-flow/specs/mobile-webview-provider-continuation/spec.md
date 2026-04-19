## MODIFIED Requirements

### Requirement: Owned mobile WebView continuation is optional and provider-gated

The system SHALL treat owned in-app WebView continuation as an optional mobile
capability that is enabled only for providers and flows that explicitly support
that mode, and may keep one app-owned browser session across the provider-owned
pages that make up that approved flow.

#### Scenario: Provider is approved for owned WebView continuation

- **GIVEN** a mobile provider flow that the product marks as compatible with
  owned WebView continuation
- **WHEN** the session reaches a challenge that requires the app-owned web
  session
- **THEN** the app starts the documented embedded WebView continuation flow
- **AND** the host continues provider resolution using that same app-owned
  browser context

#### Scenario: Approved provider flow spans multiple same-session pages

- **GIVEN** an approved mobile provider-owned browser flow starts from
  `https://calls.vk.com/`
- **WHEN** the operator authenticates and the provider flow advances to later
  VK-owned pages in that same continuation
- **THEN** the shell keeps the same app-owned browser session across those
  pages
- **AND** it does not reset app-owned cookies or storage between those steps

#### Scenario: Approved authenticated flow does not require remembered sign-in

- **GIVEN** an approved mobile provider-owned browser flow starts from
  `https://calls.vk.com/`
- **AND** the shell has no remembered embedded VK sign-in state because the
  operator cleared it or the device has not stored one
- **WHEN** the operator opens that flow inside the app-owned browser
- **THEN** the shell still starts the approved continuation from a fresh
  app-owned browser session
- **AND** support for that flow does not depend on remembered embedded sign-in
  from an earlier session

#### Scenario: Approved provider flow continues from browser-observed evidence

- **GIVEN** an approved mobile provider-owned browser flow keeps one app-owned
  browser session for the committed continuation contour
- **WHEN** the host resumes provider resolution from browser-observed stage
  evidence captured from that same embedded session
- **THEN** the flow remains eligible for owned WebView continuation
- **AND** approval does not depend on the flow exposing browser-owned replay
  requests only

#### Scenario: Provider is not approved for owned WebView continuation

- **GIVEN** a mobile provider flow that is not explicitly approved for owned
  WebView continuation
- **WHEN** the session reaches a browser-mediated challenge
- **THEN** the system does not claim embedded continuation support for that
  flow
- **AND** it keeps the documented non-WebView path or fails closed explicitly

### Requirement: Owned mobile WebView continuation fails closed when the embedded flow is not viable

The system SHALL fail closed when the embedded continuation flow cannot be
completed or validated inside the owned mobile WebView.

#### Scenario: Embedded continuation flow is blocked or incomplete

- **GIVEN** a mobile session whose challenge uses the owned in-app WebView mode
- **WHEN** the embedded flow is blocked by provider behavior, missing
  completion signals, or platform policy constraints
- **THEN** the session reports an explicit challenge or `provider_resolve`
  failure
- **AND** it does not silently claim success from the incomplete embedded
  browser flow

#### Scenario: Authenticated hosted-call flow reaches browser state without transport-ready data

- **GIVEN** an approved mobile provider flow reaches authenticated provider
  pages inside the owned browser
- **WHEN** the observed responses still do not expose transport-ready provider
  data required by the committed contour
- **THEN** the session fails explicitly
- **AND** it does not treat authenticated browser state alone as a resolved
  artifact

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

#### Scenario: Operator explicitly forgets embedded sign-in

- **GIVEN** an approved mobile owned-browser flow remembered app-owned browser
  state from an earlier embedded VK session
- **WHEN** the operator invokes the explicit reset or forget action for that
  embedded browser state
- **THEN** the shell clears the app-owned browser cookies and browser storage
  required for that remembered sign-in session
- **AND** it does not wipe saved profiles, managed providers, drafts,
  diagnostics, or unrelated shell preferences
