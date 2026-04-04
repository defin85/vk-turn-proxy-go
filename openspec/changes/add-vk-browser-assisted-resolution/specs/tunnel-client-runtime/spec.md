## MODIFIED Requirements
### Requirement: Tunnel client starts a provider-backed session

The system SHALL start the provider-backed transport path that corresponds to the accepted supervised client transport policy.

#### Scenario: Successful supervised startup

- **GIVEN** a supported client policy with a configured `connections` count
- **WHEN** the operator runs `cmd/tunnel-client`
- **THEN** the system resolves provider credentials before starting transport
- **AND** binds one shared local UDP listener for the session
- **AND** starts the configured number of supervised transport workers for the selected TURN and peer modes
- **AND** it reports a single session identity across those workers

#### Scenario: Browser-assisted provider resolution before transport startup

- **GIVEN** a supported client policy whose provider resolution becomes captcha-gated at VK stage 2
- **AND** the operator starts `cmd/tunnel-client` with interactive provider handling enabled
- **WHEN** the operator completes the challenge in a controlled browser session used for provider continuation
- **THEN** the client completes provider resolution before any local listener, TURN socket, or transport worker is started
- **AND** the session starts only after provider resolution succeeds

### Requirement: Tunnel client surfaces stage-aware startup failures

The system SHALL surface provider, transport, and supervised lifecycle failures explicitly with stage-aware errors for the accepted transport path.

#### Scenario: Browser-assisted provider resolution cannot continue

- **GIVEN** a supported client policy whose provider resolution requires browser-assisted continuation
- **WHEN** the browser-assisted provider step fails, is cancelled, or cannot supply usable continuation state
- **THEN** the client exits non-zero with `provider_resolve` as the failing stage
- **AND** it does not bind the local listener or open TURN transport resources
