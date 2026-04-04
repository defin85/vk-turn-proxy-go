## MODIFIED Requirements
### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path that corresponds to the accepted supervised client transport policy.

#### Scenario: Browser-observed provider continuation succeeds before transport startup

- **GIVEN** a supported client policy whose VK provider resolution becomes captcha-gated at stage 2
- **AND** the operator starts `cmd/tunnel-client` with interactive provider handling enabled
- **WHEN** the operator completes the challenge in a controlled browser session
- **AND** the browser completes the native VK captcha continuation chain and yields a usable repeated stage-2 result
- **THEN** the client completes provider resolution before any local listener, TURN socket, or transport worker is started
- **AND** the session starts only after provider resolution succeeds

### Requirement: Tunnel client surfaces stage-aware startup failures

The system SHALL surface provider, transport, and supervised lifecycle failures explicitly with stage-aware errors for the accepted transport path.

#### Scenario: Browser-observed provider continuation fails

- **GIVEN** a supported client policy whose provider resolution requires browser-observed continuation for VK stage 2
- **WHEN** the browser does not yield a usable repeated stage-2 result after the native captcha continuation chain
- **THEN** the client exits non-zero with `provider_resolve` as the failing stage
- **AND** it does not bind the local listener or open TURN transport resources
