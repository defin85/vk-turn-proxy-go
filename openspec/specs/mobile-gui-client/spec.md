# mobile-gui-client Specification

## Purpose
Define the mobile GUI shell contract over the mobile host bridge, including packaged-host defaults, challenge handoff, and explicit non-VPN scope.
## Requirements
### Requirement: Mobile GUI shell manages local profiles and sessions through an embedded host

The system SHALL provide a mobile GUI shell that manages profiles and sessions through a mobile host bridge instead of terminal-oriented CLI execution.
Production Android packages SHALL satisfy that bridge through a packaged app-owned host, while external bridge configuration remains limited to explicit development workflows.

#### Scenario: Production Android package boots with a packaged host

- **GIVEN** an Android production installation that includes the packaged embedded host
- **WHEN** the operator launches the mobile GUI shell
- **THEN** the app negotiates with the packaged host through the mobile host bridge
- **AND** it does not require an external `clientd`, companion app, or manual bridge configuration to reach runtime-ready state

#### Scenario: Development bridge override is explicit

- **GIVEN** an Android development build with an explicit bridge override
- **WHEN** the mobile GUI shell initializes
- **THEN** it may connect to the documented development bridge path instead of the packaged host
- **AND** that override does not redefine the default production delivery model

### Requirement: Mobile GUI shell uses platform-native challenge handoff and secure storage

The system SHALL use platform-native secure storage and browser-oriented challenge handoff for mobile profile and session management.

#### Scenario: Session requires provider challenge continuation

- **GIVEN** a mobile session that reaches a provider challenge state
- **WHEN** the operator chooses to continue from the mobile GUI
- **THEN** the app initiates the documented mobile browser handoff flow
- **AND** challenge completion or cancellation is reflected back through typed session events

#### Scenario: Profile stores runtime secrets

- **GIVEN** a mobile profile that includes provider or runtime secrets
- **WHEN** the app persists that profile locally
- **THEN** it stores those secrets through platform-native secure storage
- **AND** it does not require plaintext secret storage in general app preferences

### Requirement: First mobile GUI slice does not imply system tunnel support

The system SHALL keep the first mobile GUI slice distinct from future system-wide traffic capture support.

#### Scenario: Mobile app lacks platform tunnel integration

- **GIVEN** the first mobile GUI slice is installed without later platform tunnel capabilities
- **WHEN** the operator inspects platform support in the app
- **THEN** the app reports that system tunnel support is not yet available for that slice
- **AND** it does not silently claim device-wide traffic capture

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

### Requirement: Mobile GUI renders provider-defined settings from descriptors

The system SHALL let the mobile GUI consume the same provider-defined settings
contract as desktop without reintroducing provider-specific UI logic.

#### Scenario: Mobile shows descriptor-defined settings from the host

- **GIVEN** a mobile GUI connected to a compatible host
- **AND** the selected provider descriptor includes `provider_settings_schema`
- **WHEN** the operator opens the provider entry surface
- **THEN** the mobile GUI renders the supported provider settings from the
  descriptor metadata
- **AND** it keeps those settings separate from runtime defaults and mobile-only
  handoff actions

### Requirement: Mobile GUI does not persist prompt-only provider settings

The system SHALL keep prompt-only provider values out of ordinary mobile shell
state.

#### Scenario: Mobile persists local shell state after provider settings entry

- **GIVEN** a draft containing profile-retained settings plus `writeOnly` or
  `ephemeral` provider settings
- **WHEN** the mobile GUI persists local shell state
- **THEN** it retains only the descriptor-allowed reusable non-secret settings
- **AND** it clears prompt-only provider values from preferences, secure
  storage, and other ordinary restored state

### Requirement: Mobile GUI manages provider configs through workflow-first surfaces

The system SHALL let the mobile GUI add, edit, delete, and apply reusable
provider configs without collapsing them back into one long profile form.

#### Scenario: Mobile operator edits a provider config

- **GIVEN** a mobile GUI connected to a compatible host
- **AND** the chosen provider advertises a supported settings schema
- **WHEN** the operator opens the mobile provider-config surface
- **THEN** the app renders the same descriptor-driven provider fields used by
  desktop
- **AND** it keeps provider-config CRUD separate from runtime defaults and
  profile runtime actions

#### Scenario: Mobile blocks an incompatible provider config

- **GIVEN** a stored provider config whose provider descriptor is unavailable or
  unsupported on the connected host
- **WHEN** the operator views that config on mobile
- **THEN** the app marks it as unavailable
- **AND** it does not silently apply that config into a new draft

### Requirement: Mobile GUI offers curated preset bootstrap flows

The system SHALL provide mobile-first preset bootstrap entry points for the
primary provider families while gating those presets on host capability.

#### Scenario: Mobile starts a new draft from an available preset

- **GIVEN** the connected mobile host advertises the provider targeted by a
  preset card
- **WHEN** the operator chooses the `VK`, `WB Stream`, or `RTK Smarthome`
  preset on mobile
- **THEN** the app seeds a new workflow draft with that provider family and
  curated defaults
- **AND** the operator can continue into provider-config apply/create flows
  without re-entering the provider taxonomy manually

#### Scenario: Mobile keeps unavailable presets explicit

- **GIVEN** a preset whose target provider is not advertised by the connected
  host
- **WHEN** the operator views the mobile preset catalog
- **THEN** the app keeps that preset visible but disabled
- **AND** it explains that the current host build does not advertise the
  required provider

### Requirement: Mobile GUI shell uses workflow-first navigation

The system SHALL present the mobile GUI shell through workflow-first navigation
or drill-down destinations instead of a single fixed-height stacked dashboard.

#### Scenario: Operator opens the mobile shell

- **GIVEN** the mobile GUI shell starts on a phone-sized layout
- **WHEN** the operator lands on the primary app surface
- **THEN** the first-class mobile view focuses on profile selection or editing
  plus resolve/start actions
- **AND** resolutions, sessions, and diagnostics are reached through secondary
  destinations or drill-down surfaces rather than occupying the same initial
  dashboard stack

#### Scenario: Operator inspects live activity

- **GIVEN** the mobile GUI shell has active or recent resolutions and sessions
- **WHEN** the operator navigates from the primary workflow into activity
- **THEN** the shell presents that activity in a dedicated mobile-sized surface
- **AND** returning to the primary workflow does not discard the selected draft
  or current operator context

### Requirement: Mobile GUI shell uses progressive disclosure for advanced and secondary actions

The system SHALL use progressive disclosure for advanced runtime controls,
diagnostics, and secondary resolution/session actions on mobile-sized screens.

#### Scenario: Profile contains advanced runtime overrides

- **GIVEN** the operator is editing a mobile profile that includes advanced
  runtime overrides or verbose provider guidance
- **WHEN** the profile editor first appears
- **THEN** the primary inputs and primary actions remain immediately visible
- **AND** advanced or support-oriented content stays behind explicit disclosure

#### Scenario: Resolution exposes multiple supported actions

- **GIVEN** a mobile resolution exposes multiple supported follow-up actions
- **WHEN** the operator views that resolution on a mobile-sized layout
- **THEN** the shell presents one clear primary action for the current context
- **AND** secondary actions are available through compact affordances rather
  than a full inline action matrix
