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

### Requirement: Mobile GUI manages an app-owned provider workspace

The system SHALL let the mobile GUI create, edit, delete, and apply app-owned
managed provider records without depending on host-managed provider-config CRUD
as the primary reusable-provider workflow.

#### Scenario: Mobile shows the supported provider catalog from the app

- **GIVEN** the shared app-owned provider catalog includes shipped supported
  providers such as `VK Calls` and `Generic TURN`
- **WHEN** the operator opens the mobile provider workspace
- **THEN** the workspace lists those supported providers even if the connected
  mobile host does not advertise a reusable `provider_settings_schema`
- **AND** the UI shows current host availability as an overlay instead of
  removing the provider from the workspace

#### Scenario: Mobile edits a managed provider record

- **GIVEN** a supported provider family in the app-owned catalog
- **WHEN** the operator creates or edits a managed provider record on mobile
- **THEN** the mobile shell stores that record in shell-owned state
- **AND** that record contains only reusable non-secret provider-owned values
- **AND** later profile drafts can apply it by snapshot copy
- **AND** editing the managed provider record does not silently mutate already
  saved profiles

#### Scenario: Mobile managed provider can have zero reusable fields

- **GIVEN** a shipped supported provider family whose first managed-provider
  slice exposes zero reusable provider-owned fields
- **WHEN** the operator views that provider in the mobile provider workspace
- **THEN** the mobile shell still lists it as a supported managed provider
- **AND** the UI does not invent placeholder editable fields just to fill the
  form

### Requirement: Mobile GUI offers curated preset bootstrap flows

The system SHALL provide mobile-first preset bootstrap entry points that seed
managed provider drafts or records for the primary provider families.

#### Scenario: Mobile starts a new draft from an available preset

- **GIVEN** a mobile preset for a shipped supported provider family
- **WHEN** the operator chooses the `VK`, `WB Stream`, or `RTK Smarthome`
  preset on mobile
- **THEN** the app seeds a new managed provider draft or record for that
  provider family
- **AND** the preset does not pretend to be a separate provider identity

#### Scenario: Mobile keeps unavailable presets explicit

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the operator views the mobile preset catalog
- **THEN** it does not show a preset for that unsupported provider family
- **AND** it does not imply support through placeholder cards

### Requirement: Mobile profile editor supports managed-provider and custom modes

The system SHALL let the mobile profile workspace start from either a managed
provider record or a custom provider path.

#### Scenario: Mobile profile uses a managed provider

- **GIVEN** an existing managed provider record in mobile shell state
- **WHEN** the operator selects that managed provider while editing a profile
- **THEN** the profile draft inherits the provider family and editable
  provider-owned settings by snapshot
- **AND** the operator can still edit profile-local runtime defaults

#### Scenario: Mobile reopens a saved managed-provider profile in managed mode

- **GIVEN** a saved mobile profile that was last edited from a managed provider
  record
- **WHEN** the operator reopens that profile in the mobile shell
- **THEN** the shell restores managed-provider mode for that profile workspace
- **AND** it does not silently reopen the profile as if it were an unrelated
  custom-provider draft

#### Scenario: Mobile profile uses a custom provider path

- **GIVEN** an operator who needs a raw provider entry path not backed by a
  managed provider record
- **WHEN** they switch the mobile profile workspace to custom provider mode
- **THEN** the editor accepts direct provider and input values
- **AND** prompt-only or session-scoped inputs remain profile-local instead of
  being persisted back into the managed-provider catalog
- **AND** that custom path does not mutate the managed-provider catalog

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

### Requirement: Mobile browser handoff may auto-resume once on documented app return

The system SHALL allow the mobile shell to issue at most one best-effort automatic challenge continue per active eligible challenge when the challenge metadata declares an app-return-compatible handoff mode and the app receives a matching documented return signal for that challenge.

#### Scenario: App return triggers one automatic continue attempt

- **GIVEN** a mobile session with an active provider challenge that advertises app-return-assisted continuation
- **AND** the challenge metadata reports the supported return-signal kind for that challenge
- **AND** the operator completes the browser step and returns to the app through the documented return path or supported foreground-resume path
- **WHEN** the mobile shell processes that matching return signal while the same challenge is still active
- **THEN** it issues one automatic continue request through the mobile host bridge
- **AND** it renders the resulting typed session or challenge updates without requiring an immediate second tap by default

#### Scenario: Repeated lifecycle noise does not loop automatic continue

- **GIVEN** a mobile session with an active provider challenge that already triggered its one automatic continue attempt
- **WHEN** the app receives repeated foreground resumes or duplicate return callbacks before the host emits a new eligible challenge
- **THEN** the mobile shell does not issue a second automatic continue for that challenge
- **AND** it waits for typed host updates or explicit operator action

### Requirement: Mobile browser handoff keeps explicit fallback confirmation

The system SHALL keep explicit post-browser confirmation controls whenever automatic continuation is unavailable, ambiguous, or insufficient to complete provider resolution.

#### Scenario: Automatic continue is not supported for the challenge

- **GIVEN** a mobile session with an active provider challenge that does not advertise app-return-assisted continuation
- **WHEN** the operator returns from the browser flow to the app
- **THEN** the mobile shell keeps an explicit post-browser confirmation action
- **AND** it does not imply that returning to the app alone completed provider resolution

#### Scenario: Automatic continue does not complete the challenge

- **GIVEN** a mobile session whose challenge triggered one automatic continue attempt on app return
- **WHEN** the host remains in `challenge_required` or fails during `provider_resolve`
- **THEN** the mobile shell restores or keeps explicit post-browser completion and cancellation actions
- **AND** the shell reports the typed failure or updated challenge state instead of looping automatic continues

### Requirement: Mobile browser handoff keeps browser-launch and post-browser completion semantics distinct

The system SHALL keep the action that opens or re-opens the browser handoff distinct from any post-browser confirmation action so operators can tell whether the app will launch the browser or ask the host to continue.

#### Scenario: Challenge surface distinguishes launch from completion

- **GIVEN** a mobile session with an active provider challenge and visible browser handoff controls
- **WHEN** the shell renders that challenge before or after the browser step
- **THEN** the browser-launch control is presented as a launch or re-open action
- **AND** any manual fallback continuation control is presented as post-browser completion rather than another browser-launch action
- **AND** automatic continuation, when supported, does not relabel browser launch as proof that provider resolution already succeeded

### Requirement: Mobile shell chooses the documented challenge surface per typed challenge mode

The system SHALL let the mobile shell choose between system-browser handoff and an owned in-app WebView challenge surface from typed challenge metadata instead of provider-specific UI heuristics.

#### Scenario: Challenge requires owned in-app web session

- **GIVEN** a mobile session whose active challenge advertises an owned in-app WebView continuation mode
- **WHEN** the operator continues that challenge from the mobile GUI
- **THEN** the mobile shell presents the documented in-app challenge surface instead of launching the system browser
- **AND** it continues to render typed session and challenge updates through the same host bridge contract

#### Scenario: Challenge stays on system-browser handoff

- **GIVEN** a mobile session whose active challenge does not advertise owned in-app WebView continuation
- **WHEN** the operator continues that challenge from the mobile GUI
- **THEN** the mobile shell uses the documented system-browser handoff path
- **AND** it does not silently substitute an embedded web surface
