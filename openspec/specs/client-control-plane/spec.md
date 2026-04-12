# client-control-plane Specification

## Purpose
TBD - created by archiving change add-01-client-control-plane. Update Purpose after archive.
## Requirements
### Requirement: Client control plane manages profiles and sessions through a stable local API

The system SHALL expose a stable local control plane for profile management and session lifecycle operations.

#### Scenario: GUI starts a session through the control plane

- **GIVEN** a stored profile with valid runtime parameters
- **WHEN** a local client shell asks the control plane to start a session
- **THEN** the control plane creates a typed session record
- **AND** it returns a stable session identifier instead of requiring the caller to parse CLI output

#### Scenario: GUI stops a running session through the control plane

- **GIVEN** a running local session
- **WHEN** a local client shell asks the control plane to stop it
- **THEN** the control plane terminates the corresponding runtime attempt
- **AND** it reports the terminal state through the same typed API

### Requirement: Client control plane streams typed runtime events

The system SHALL stream typed local events for session lifecycle, readiness, retries, failures, and provider challenges.

#### Scenario: Provider challenge is surfaced to the GUI

- **GIVEN** a session whose provider resolution requires operator action
- **WHEN** the runtime reaches that challenge state
- **THEN** the control plane emits a typed challenge event with a stable challenge identifier
- **AND** the GUI can continue or cancel the challenge without parsing human log text

#### Scenario: Runtime reaches ready state

- **GIVEN** a session that completes provider resolution and transport startup successfully
- **WHEN** the runtime becomes ready
- **THEN** the control plane emits a typed ready event for that session
- **AND** readiness is associated with the session identifier exposed by the control plane

### Requirement: Client control plane exposes capability and version negotiation

The system SHALL expose the local host capabilities and a versioned contract so GUI shells can reject incompatible hosts explicitly.

#### Scenario: GUI detects incompatible local host

- **GIVEN** a local GUI shell and a host implementation that do not share a compatible control-plane version
- **WHEN** the GUI connects to the host
- **THEN** the host reports the incompatibility explicitly
- **AND** the GUI does not attempt to start or manage sessions through an undefined API

### Requirement: Client control plane exposes provider catalog discovery

The system SHALL expose a typed provider catalog through the local control
plane so shells can render provider entry flows from host-reported metadata.

#### Scenario: Shell requests provider catalog from a compatible host

- **GIVEN** a local shell connected to a compatible host
- **WHEN** the shell requests the available providers
- **THEN** the host returns typed provider descriptors and capability metadata
- **AND** the shell does not need to hard-code provider-specific workflow rules

#### Scenario: Provider descriptor exposes auth and browser policy

- **GIVEN** a provider whose supported flow depends on account auth, guest auth,
  or a specific browser surface
- **WHEN** a shell requests provider descriptors from the host
- **THEN** the control plane returns typed auth and browser-policy metadata for
  that provider
- **AND** the shell can reject unsupported local continuation surfaces before
  starting resolution

### Requirement: Client control plane negotiates multi-provider support explicitly

The system SHALL advertise the add-20 provider catalog and artifact-family
surface through an explicit host capability so updated shells can fail closed
against older handoff-only hosts.

#### Scenario: Updated shell negotiates against an older host

- **GIVEN** a shell build that expects provider catalog discovery and
  artifact-family actions from this change
- **WHEN** it negotiates with a host that only implements the older
  `provider-resolution-handoff` surface
- **THEN** the host does not falsely claim the add-20 capability
- **AND** the shell can reject the host as incompatible before rendering
  descriptor-driven or artifact-family-specific UX

#### Scenario: Shipped add-20 host does not keep the legacy handoff bridge

- **GIVEN** a host build that has completed the add-20 rollout
- **WHEN** an updated shell negotiates with that host
- **THEN** the host advertises the add-20 capability for provider catalog and
  artifact-family UX
- **AND** it does not rely on `provider-resolution-handoff` as a compatibility
  bridge for those flows

### Requirement: Client control plane accepts typed provider inputs

The system SHALL accept provider-resolution start requests through a typed input
envelope that matches the selected provider descriptor.

#### Scenario: Shell starts resolution from a descriptor-declared input kind

- **GIVEN** a provider descriptor that declares a specific input kind for
  resolution start
- **WHEN** a shell starts resolution for that provider
- **THEN** the request carries the provider identifier plus a typed input
  envelope that matches the declared kind
- **AND** the host does not require the shell to guess semantics from one
  untyped string field alone

#### Scenario: Legacy untyped start request is rejected after migration

- **GIVEN** a caller that still uses the removed legacy request shape instead
  of the typed input envelope
- **WHEN** it starts resolution against a shipped add-20 host
- **THEN** the host rejects that request explicitly
- **AND** it does not silently reinterpret the payload as a descriptor-matched
  typed input

### Requirement: Client control plane reports typed resolution artifacts

The system SHALL surface provider resolution state through typed artifact-family
records instead of assuming every successful resolution becomes a runtime
session or `generic-turn` export.

#### Scenario: Host returns artifact family and actions for a resolution

- **GIVEN** a provider resolution record exposed through the control plane
- **WHEN** a shell reads that record or receives its events
- **THEN** the host includes the artifact family, stable machine-readable
  supported actions, and redacted summary fields for the resolved provider
  result
- **AND** the host keeps resolution state separate from runtime session state

### Requirement: Client control plane fails closed for unsupported artifact actions

The system SHALL report explicit stage-aware failures when a caller requests an
action that the resolved artifact family or current host build does not support.

#### Scenario: Shell requests unsupported same-device execution

- **GIVEN** a resolved artifact family whose requested same-device action is
  unsupported by the current host build
- **WHEN** the shell requests that action through the control plane
- **THEN** the host returns a typed failure that identifies the unsupported
  action or missing executor stage
- **AND** it does not create a fake session or guessed fallback artifact

### Requirement: Client control plane accepts descriptor-declared provider settings

The system SHALL let providers declare reusable user-configurable settings as
part of the provider entry contract without requiring shell-specific hard-coded
fields.

#### Scenario: Shell starts resolution with validated provider settings

- **GIVEN** a provider descriptor that includes a `provider_settings_schema`
- **WHEN** a shell starts resolution for that provider
- **THEN** the request may include a `provider_settings` object in addition to
  the typed input envelope
- **AND** the host validates that object against the descriptor-declared schema
  before resolution begins
- **AND** the host rejects undeclared or invalid setting keys instead of
  ignoring them

### Requirement: Saved profiles keep only profile-retained provider settings

The system SHALL keep reusable provider settings separate from ephemeral
provider entry values and runtime defaults.

#### Scenario: Shell saves a profile with provider settings

- **GIVEN** a provider descriptor whose settings schema marks some fields as
  `profile` retained and others as `ephemeral`
- **WHEN** a shell upserts a saved profile
- **THEN** the profile contract stores only the `profile`-retained provider
  settings
- **AND** it does not persist `writeOnly` or `ephemeral` provider setting
  values as part of the saved profile

### Requirement: Invalid provider settings fail with field-aware errors

The system SHALL report provider-setting validation failures through typed
errors that identify the failing field and rule.

#### Scenario: Shell submits an invalid provider setting

- **GIVEN** a descriptor-declared provider settings schema
- **WHEN** a caller sends a missing, undeclared, or shape-invalid provider
  setting
- **THEN** the host returns an explicit validation failure
- **AND** the failure identifies the provider-setting key plus a stable
  violation code such as `required`, `unknown`, `type`, `enum`, or `pattern`
- **AND** the host does not silently coerce the invalid setting into a guessed
  value

