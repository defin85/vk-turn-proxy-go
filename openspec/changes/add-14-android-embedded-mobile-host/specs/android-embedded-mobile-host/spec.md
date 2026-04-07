## ADDED Requirements
### Requirement: Android app package includes a compatible embedded host

The system SHALL package a compatible Android embedded host with the mobile app so production installs do not depend on an external runtime binary, sidecar, or first-run host download.

#### Scenario: First launch without network bootstrap

- **GIVEN** an Android app install on a device with no prior local host state
- **WHEN** the operator launches the app for the first time
- **THEN** the packaged embedded host is the runtime source used by the mobile GUI shell
- **AND** the app does not require downloading or locating an external client binary before session control can start

### Requirement: Android embedded host preserves canonical control-plane semantics

The system SHALL expose the Android embedded host through the existing mobile host semantics so profile, session, challenge, diagnostics, build identity, and compatibility behavior remain consistent with the canonical repository runtime.

#### Scenario: GUI negotiates capabilities against packaged host

- **GIVEN** an Android app with a packaged embedded host
- **WHEN** the mobile GUI shell initializes its host bridge
- **THEN** the packaged host reports the expected control-plane contract and required capabilities
- **AND** the GUI fails closed if the packaged host is missing or incompatible

### Requirement: Development bridge overrides stay non-default on Android

The system SHALL treat external Android bridge endpoints as explicit development overrides rather than the default production runtime model.

#### Scenario: Production package lacks a usable packaged host

- **GIVEN** an Android production package where the packaged host cannot bootstrap successfully
- **WHEN** the mobile GUI shell starts
- **THEN** the app reports the packaged-host failure explicitly
- **AND** it does not silently fall back to a development bridge endpoint

#### Scenario: Development build targets an external bridge

- **GIVEN** an Android development build with a documented external bridge override
- **WHEN** the operator runs that build for debugging or compatibility work
- **THEN** the app may use the explicit override instead of the packaged host
- **AND** that path remains a development-only exception to the production packaging model
