# desktop-gui-client Specification

## Purpose
Define the desktop GUI shell contract over the local host, including profile/session workflows, sidecar supervision, diagnostics, and challenge handoff.
## Requirements
### Requirement: Desktop GUI shell manages local profiles and sessions

The system SHALL provide a desktop GUI shell that manages profiles and sessions through the local client control plane.

#### Scenario: Operator starts a profile from the desktop GUI

- **GIVEN** a desktop installation with a compatible local host
- **WHEN** the operator starts a saved profile from the desktop GUI
- **THEN** the GUI requests session startup through the control plane
- **AND** it renders typed state transitions for that session without requiring terminal interaction

#### Scenario: Operator inspects session diagnostics from the desktop GUI

- **GIVEN** a running or failed session
- **WHEN** the operator opens diagnostics in the desktop GUI
- **THEN** the GUI can show or export the host-provided diagnostics bundle for that session

### Requirement: Desktop GUI shell supervises a compatible local host

The system SHALL ensure that the desktop GUI interacts only with a compatible local host process.

#### Scenario: Compatible host is not running

- **GIVEN** the desktop GUI starts and no compatible local host is available
- **WHEN** the GUI initializes runtime management
- **THEN** it starts or prompts for the local host explicitly
- **AND** it does not attempt to manage sessions through an unavailable host

#### Scenario: Host version is incompatible

- **GIVEN** the desktop GUI finds a local host with an incompatible control-plane version
- **WHEN** compatibility negotiation runs
- **THEN** the GUI reports the incompatibility explicitly
- **AND** it blocks session management until a compatible host is available

### Requirement: Desktop GUI shell supports browser-oriented challenge handoff

The system SHALL let the desktop GUI coordinate provider challenges without embedding provider behavior into the UI shell.

#### Scenario: Session requires browser challenge continuation

- **GIVEN** a desktop session that reaches a provider challenge state
- **WHEN** the operator chooses to continue from the GUI
- **THEN** the GUI initiates the documented browser handoff flow through the host
- **AND** the resulting challenge completion or cancellation is reflected back through typed session events

### Requirement: Desktop GUI shell persists local profile settings

The system SHALL persist desktop-shell profile settings locally so operators do not need to recreate them after every GUI or local-host restart.

#### Scenario: Restarting the desktop shell restores saved profiles

- **GIVEN** a desktop operator has saved one or more profiles in the GUI shell
- **WHEN** the GUI shell restarts and reconnects to a compatible local host
- **THEN** it restores those saved profiles into the GUI state
- **AND** it rehydrates them back into the local host without requiring the operator to re-enter them manually

#### Scenario: Restarting the desktop shell restores the selected profile and draft

- **GIVEN** the desktop operator has a selected profile or an in-progress draft in the GUI shell
- **WHEN** the GUI shell restarts
- **THEN** it restores the selected profile and draft values from local persistence
- **AND** it does not require the operator to rebuild the form state from scratch

### Requirement: Desktop GUI shell renders provider entry from host descriptors

The system SHALL let the desktop GUI build provider entry flows from
host-reported descriptors rather than from hard-coded provider-name-specific
assumptions.

#### Scenario: Operator starts a provider flow from a descriptor-driven form

- **GIVEN** a desktop GUI connected to a compatible host
- **WHEN** the operator opens the provider entry surface
- **THEN** the GUI renders provider-specific input and continuation guidance
  from the host-reported descriptor metadata
- **AND** it does not require desktop-specific VK-only assumptions to discover
  the correct workflow

#### Scenario: Desktop GUI respects external-browser-required providers

- **GIVEN** a provider descriptor that reports an external-browser requirement
  for auth or continuation
- **WHEN** the operator starts that provider flow from desktop
- **THEN** the GUI uses the supported external-browser path
- **AND** it does not silently substitute an embedded browser surface

### Requirement: Desktop GUI shell presents post-resolution actions from artifact capabilities

The system SHALL let the desktop GUI present post-resolution actions according
to the resolved artifact family and host-reported capabilities.

#### Scenario: Desktop GUI shows only supported actions for a resolved artifact

- **GIVEN** a resolved provider artifact exposed through the local host
- **WHEN** the desktop GUI renders the resolved state
- **THEN** it shows only the actions that the host reported as supported for
  that artifact family
- **AND** actions such as same-device start, export, room open, or camera open
  are not inferred from the provider name alone

### Requirement: Desktop GUI shell keeps unsupported families honest

The system SHALL keep unsupported or partially supported artifact families
fail-closed in desktop UX.

#### Scenario: Resolved artifact lacks local desktop execution support

- **GIVEN** a resolved provider artifact whose family is discoverable but not
  executable by the current desktop host build
- **WHEN** the GUI renders the resolved state
- **THEN** it reports that the artifact is not supported for local desktop
  execution
- **AND** it does not present the artifact as a ready local runtime session

### Requirement: Desktop GUI renders provider-defined settings generically

The system SHALL let the desktop GUI render provider-defined settings from
host-reported descriptor metadata rather than from provider-name-specific form
branches.

#### Scenario: Desktop shows descriptor-defined settings without provider branching

- **GIVEN** a provider descriptor with `provider_settings_schema`
- **WHEN** the operator opens the provider entry surface
- **THEN** the desktop GUI renders supported controls from the schema
  annotations and `x-vkturn-*` hints
- **AND** it keeps provider settings visually separate from runtime defaults
- **AND** it does not add desktop-only provider-specific form code for that
  provider

### Requirement: Desktop GUI persists only allowed provider settings locally

The system SHALL keep prompt-only provider values out of ordinary desktop shell
state.

#### Scenario: Desktop persists a draft containing profile-retained and prompt-only fields

- **GIVEN** a draft with both profile-retained and prompt-only provider settings
- **WHEN** the desktop GUI saves local shell state or a saved profile
- **THEN** it keeps only the descriptor-allowed profile-retained non-secret
  settings in persisted state
- **AND** it clears link-like, write-only, or `ephemeral` provider setting
  values from plaintext local state

### Requirement: Desktop GUI manages a provider-config library

The system SHALL let the desktop GUI add, edit, delete, and apply reusable
provider configs without mixing them into runtime-default editing.

#### Scenario: Desktop operator edits reusable provider settings

- **GIVEN** a desktop GUI connected to a compatible host
- **AND** the host advertises a provider descriptor with a supported settings
  schema
- **WHEN** the operator opens the provider-config surface
- **THEN** the GUI renders schema-driven provider fields for add/edit/delete
  flows
- **AND** it keeps provider-config editing visually separate from runtime
  defaults and profile-input editing

#### Scenario: Desktop blocks apply for an unavailable provider config

- **GIVEN** a stored provider config whose provider descriptor is unavailable or
  incompatible on the connected host
- **WHEN** the operator views that config on desktop
- **THEN** the GUI marks it as unavailable
- **AND** it blocks apply/startup actions instead of silently mapping it to a
  different provider shape

### Requirement: Desktop GUI offers preset profile bootstrap cards

The system SHALL offer curated desktop preset entry points for the primary
provider families while staying honest about current host support.

#### Scenario: Desktop bootstrap uses an available preset

- **GIVEN** the connected host advertises the provider descriptor targeted by
  one of the preset cards
- **WHEN** the operator chooses the `VK`, `WB Stream`, or `RTK Smarthome`
  preset on desktop
- **THEN** the GUI seeds a new draft with that preset's provider family and
  curated defaults
- **AND** the operator can continue by applying or creating a provider config
  before saving or starting a profile

#### Scenario: Desktop shows a disabled preset for an unavailable provider

- **GIVEN** a preset whose target provider is not advertised by the connected
  host
- **WHEN** the operator views the preset catalog on desktop
- **THEN** the preset remains visible with explicit unavailable copy
- **AND** the GUI does not silently create a fake draft for that provider

### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a workflow-first workspace
where saved-profile navigation is distinct from the active editor and live work
surface.

#### Scenario: Operator switches between saved profiles

- **GIVEN** the desktop GUI shell has multiple saved profiles
- **WHEN** the operator selects a profile from the saved-profile navigation
- **THEN** the active workspace updates to that profile's draft and actions
- **AND** saved-profile navigation remains available without mixing the full
  editor into the same navigation surface

#### Scenario: Shell opens with no active runtime work

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the primary visual focus is profile creation, selection, and
  resolve/start actions
- **AND** empty resolutions, sessions, and event diagnostics do not occupy the
  dominant workspace area

### Requirement: Desktop GUI shell consolidates operational state

The system SHALL present host readiness, compatibility, notices, and
platform-tunnel summary through one consolidated operational header with
progressive disclosure for secondary detail.

#### Scenario: Host is ready but platform tunnel support is unavailable

- **GIVEN** the desktop GUI shell is connected to a compatible host
- **AND** the packaged host reports no available platform-tunnel mode
- **WHEN** the operator views the main shell screen
- **THEN** the shell shows one consolidated operational summary instead of
  separate competing top-of-screen banners
- **AND** the operator can still inspect the platform-tunnel explanation

#### Scenario: Host is blocked or incompatible

- **GIVEN** the desktop GUI shell cannot manage runtime work because the host is
  blocked or incompatible
- **WHEN** the operator views the shell
- **THEN** the consolidated operational header explicitly reports the blocked
  state and required operator action
- **AND** the shell does not hide that failure behind secondary diagnostics
