## ADDED Requirements
### Requirement: Owned mobile WebView continuation is optional and provider-gated

The system SHALL treat owned in-app WebView continuation as an optional mobile capability that is enabled only for providers and flows that explicitly support that mode.

#### Scenario: Provider is approved for owned WebView continuation

- **GIVEN** a mobile provider flow that the product marks as compatible with owned WebView continuation
- **WHEN** the session reaches a challenge that requires the app-owned web session
- **THEN** the app starts the documented embedded WebView continuation flow
- **AND** the host continues provider resolution using that same app-owned browser context

#### Scenario: Provider is not approved for owned WebView continuation

- **GIVEN** a mobile provider flow that is not explicitly approved for owned WebView continuation
- **WHEN** the session reaches a browser-mediated challenge
- **THEN** the system does not claim embedded continuation support for that flow
- **AND** it keeps the documented non-WebView path or fails closed explicitly

### Requirement: Owned mobile WebView continuation preserves app-owned session boundaries

The system SHALL keep embedded continuation state inside app-managed WebView storage and must not import session state from the user's external browser profile.

#### Scenario: Embedded continuation keeps browser state inside the app sandbox

- **GIVEN** a mobile challenge that runs through an owned in-app WebView
- **WHEN** provider continuation needs cookies, storage, or other browser-backed state from that flow
- **THEN** the runtime uses the app-owned embedded session state for that continuation
- **AND** it does not read cookies or profile data from the user's regular browser installation

### Requirement: Owned mobile WebView continuation fails closed when the embedded flow is not viable

The system SHALL fail closed when the embedded continuation flow cannot be completed or validated inside the owned mobile WebView.

#### Scenario: Embedded continuation flow is blocked or incomplete

- **GIVEN** a mobile session whose challenge uses the owned in-app WebView mode
- **WHEN** the embedded flow is blocked by provider behavior, missing completion signals, or platform policy constraints
- **THEN** the session reports an explicit challenge or `provider_resolve` failure
- **AND** it does not silently claim success from the incomplete embedded browser flow
