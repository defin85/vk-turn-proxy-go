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
