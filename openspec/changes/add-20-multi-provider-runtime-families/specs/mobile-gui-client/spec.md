## ADDED Requirements
### Requirement: Mobile GUI shell consumes the shared provider catalog

The system SHALL let the mobile GUI consume the same typed provider catalog as
desktop while keeping platform presentation separate from host semantics.

#### Scenario: Mobile GUI discovers providers from the embedded host

- **GIVEN** a mobile GUI connected to a compatible embedded host
- **WHEN** the app requests the provider catalog
- **THEN** it receives the same descriptor and artifact-family metadata that a
  desktop shell would consume
- **AND** auth and browser-policy constraints are included in that shared
  metadata
- **AND** the app does not need a separate provider taxonomy for mobile

### Requirement: Mobile GUI shell renders capability-driven artifact actions

The system SHALL let the mobile GUI render post-resolution actions from the
resolved artifact family and host-reported capabilities.

#### Scenario: Mobile GUI offers only supported platform-native actions

- **GIVEN** a resolved provider artifact
- **WHEN** the app renders the resolved state
- **THEN** it offers only the actions that the host reported as supported for
  that artifact family on the current mobile build
- **AND** platform-native copy, share, browser, or open actions remain thin
  mobile adapters over the shared host contract

#### Scenario: Mobile GUI does not fake embedded continuation for external-browser providers

- **GIVEN** a provider descriptor that requires an external browser for auth or
  continuation
- **WHEN** the app starts that provider flow
- **THEN** the app uses the supported external-browser handoff
- **AND** it does not silently downgrade the flow to an unsupported embedded
  browser surface

### Requirement: Mobile GUI shell stays fail-closed for unsupported local execution

The system SHALL keep unsupported artifact families explicit on mobile instead
of claiming local execution support that the build does not provide.

#### Scenario: Mobile build cannot execute the resolved artifact locally

- **GIVEN** a resolved artifact family that the current mobile build cannot
  execute on-device
- **WHEN** the app renders its resolved state
- **THEN** it reports that local execution is unavailable for that artifact
  family on the current build
- **AND** it does not silently present a fake ready/runtime state
