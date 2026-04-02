## ADDED Requirements

### Requirement: Client runtime supports an explicit transport policy matrix

The system SHALL support the documented client transport policy combinations instead of silently collapsing all runtime behavior to the first-slice defaults.

#### Scenario: TURN transport mode selection

- **GIVEN** a supported client configuration with `mode=udp`, `mode=tcp`, or `mode=auto`
- **WHEN** the client session starts
- **THEN** the runtime uses the documented TURN transport path for that mode
- **AND** it does not silently switch to a different transport mode

#### Scenario: DTLS disabled runtime path

- **GIVEN** a supported client configuration with `dtls=false`
- **WHEN** the client session starts
- **THEN** the runtime starts the non-DTLS path explicitly
- **AND** it does not silently force DTLS on

#### Scenario: Bind interface requested

- **GIVEN** a supported client configuration with `bind-interface`
- **WHEN** the runtime starts outbound transport setup
- **THEN** it uses the requested bind target when possible
- **AND** it fails explicitly when the requested bind target cannot be applied
