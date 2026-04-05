## MODIFIED Requirements
### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path only after provider resolution yields supported transport credentials.

#### Scenario: Browser-observed post-preview contour is still not transport-ready

- **GIVEN** a supported client policy whose VK provider resolution progresses beyond `calls.getCallPreview` into a browser-observed post-preview contour
- **WHEN** that contour still does not yield normalized TURN credentials
- **THEN** `cmd/tunnel-client` exits non-zero at `provider_resolve`
- **AND** it does not bind the local listener or open TURN transport resources
