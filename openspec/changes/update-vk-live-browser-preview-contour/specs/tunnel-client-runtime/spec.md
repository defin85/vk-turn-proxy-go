## MODIFIED Requirements
### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path only after provider resolution yields supported transport credentials.

#### Scenario: Live browser preview contour is not yet transport-ready

- **GIVEN** a supported client policy whose VK provider resolution reaches a browser-observed pre-join preview contour
- **WHEN** that contour does not yet yield normalized TURN credentials
- **THEN** `cmd/tunnel-client` exits non-zero at `provider_resolve`
- **AND** it does not bind the local listener or open TURN transport resources
