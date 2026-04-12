## ADDED Requirements
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
