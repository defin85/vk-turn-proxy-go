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

### Requirement: Desktop GUI manages an app-owned provider workspace

The system SHALL let the desktop GUI create, edit, delete, and apply app-owned
managed provider records without depending on host-managed provider-config CRUD
as the primary reusable-provider workflow.

#### Scenario: Desktop shows the supported provider catalog from the app

- **GIVEN** the shared app-owned provider catalog includes shipped supported
  providers such as `VK Calls` and `Generic TURN`
- **WHEN** the operator opens the desktop provider workspace
- **THEN** the workspace lists those supported providers even if the current
  host does not advertise a reusable `provider_settings_schema`
- **AND** the UI shows current host availability as an overlay instead of
  making the provider disappear

#### Scenario: Desktop edits a managed provider record

- **GIVEN** a supported provider family in the app-owned catalog
- **WHEN** the operator creates or edits a managed provider record on desktop
- **THEN** the desktop shell stores that record in shell-owned state
- **AND** that record contains only reusable non-secret provider-owned values
- **AND** later profile drafts can apply it by snapshot copy
- **AND** editing the managed provider record does not silently mutate already
  saved profiles

#### Scenario: Desktop managed provider can have zero reusable fields

- **GIVEN** a shipped supported provider family whose first managed-provider
  slice exposes zero reusable provider-owned fields
- **WHEN** the operator views that provider in the desktop provider workspace
- **THEN** the desktop shell still lists it as a supported managed provider
- **AND** the UI does not invent placeholder editable fields just to fill the
  form

### Requirement: Desktop profile editor supports managed-provider and custom modes

The system SHALL let the desktop profile workspace start from either a managed
provider record or a custom provider path.

#### Scenario: Desktop profile uses a managed provider

- **GIVEN** an existing managed provider record in desktop shell state
- **WHEN** the operator selects that managed provider while editing a profile
- **THEN** the profile draft inherits the provider family and editable
  provider-owned settings by snapshot
- **AND** the operator can still edit profile-local runtime defaults

#### Scenario: Desktop reopens a saved managed-provider profile in managed mode

- **GIVEN** a saved desktop profile that was last edited from a managed
  provider record
- **WHEN** the operator reopens that profile in the desktop shell
- **THEN** the shell restores managed-provider mode for that profile workspace
- **AND** it does not silently reopen the profile as if it were an unrelated
  custom-provider draft

#### Scenario: Desktop profile uses a custom provider path

- **GIVEN** an operator who needs a raw provider entry path not backed by a
  managed provider record
- **WHEN** they switch the desktop profile workspace to custom provider mode
- **THEN** the editor accepts direct provider and input values
- **AND** prompt-only or session-scoped inputs remain profile-local instead of
  being persisted back into the managed-provider catalog
- **AND** that custom path does not mutate the managed-provider catalog

### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a left-pad workspace where
large desktop widths keep a compact persistent navigation pad on the left,
narrower desktop widths expose the same workflow and task-entry commands
through a compact drawer or equivalent trigger, and one main canvas owns the
active task surface.

#### Scenario: Shell opens into one active canvas route in routine ready state

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the shell shows a compact left pad plus one dominant main-canvas
  task route
- **AND** the shell does not stack multiple explanatory context cards or
  route-restating action cards beside or above the active canvas route
- **AND** the shell does not present a second persistent peer region that
  competes with the active canvas route for substantive operator attention
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant region

#### Scenario: Operator switches task entry from the left pad

- **GIVEN** the operator is inside the desktop shell
- **WHEN** the operator uses the left pad to switch workflows or open a task
  entry surface
- **THEN** the main canvas changes to the requested route
- **AND** the left pad remains a stable navigation surface instead of becoming
  a second detail pane
- **AND** routine task-entry commands do not require a separate persistent
  explanatory card above the active route

#### Scenario: Narrow desktop widths collapse the left pad without changing the active task

- **GIVEN** the desktop GUI shell is running in a narrower desktop-width window
- **WHEN** the operator opens workflow navigation or task-entry commands
- **THEN** the shell exposes the same workflow and task-entry actions through a
  compact drawer or equivalent trigger
- **AND** opening or closing that compact navigation surface does not discard
  the active canvas route, draft state, or active selection
- **AND** the shell does not restore a separate persistent summary pane beside
  the active canvas as a fallback for the collapsed left pad

### Requirement: Desktop GUI shell consolidates operational state

The system SHALL present routine desktop host readiness as a compact assurance
surface while preserving explicit pinned guidance for blocked or incompatible
states.

#### Scenario: Host is ready in the normal desktop path

- **GIVEN** the desktop GUI shell is connected to a compatible host
- **AND** there is no blocked host condition that requires immediate operator
  intervention
- **WHEN** the operator views the main shell screen
- **THEN** the shell shows a compact readiness and capability summary adjacent
  to the active workflow
- **AND** that routine assurance does not visually outrank the dominant editor

#### Scenario: Host is blocked or incompatible

- **GIVEN** the desktop GUI shell cannot manage runtime work because the host is
  blocked or incompatible
- **WHEN** the operator views the shell
- **THEN** the shell pins explicit guidance and required operator action from
  the primary shell surface
- **AND** it does not hide that failure behind secondary support affordances

### Requirement: Desktop GUI shell keeps diagnostics and live work in secondary inspectors

The system SHALL keep diagnostics, tunnel detail, event stream, and live
runtime support surfaces secondary by default while making them explicitly
reachable and escalating them when state demands it.

#### Scenario: Routine ready state keeps support on demand

- **GIVEN** the desktop GUI shell is in a routine ready state
- **WHEN** the operator is working in the dominant workflow editor
- **THEN** diagnostics and live runtime support stay collapsed or secondary by
  default
- **AND** the operator can open them through explicit support affordances
- **AND** closing support returns focus to the current workflow without losing
  the current draft or selection

#### Scenario: Blocked or active runtime state escalates support visibility

- **GIVEN** the host is blocked or incompatible, or the shell has active
  runtime work that exposes typed support detail
- **WHEN** the operator reaches the main desktop shell
- **THEN** the shell keeps the relevant support summary immediately visible
  from the primary surface
- **AND** the full support detail remains reachable through the inspector model
  without turning routine ready-state into a permanent support dashboard

#### Scenario: Support inspector adapts across desktop widths

- **GIVEN** the operator has opened diagnostics or live runtime support from
  the focused workflow shell
- **WHEN** the desktop width no longer supports the current coplanar support
  presentation
- **THEN** the shell transitions support into a narrower desktop-appropriate
  presentation such as an end drawer or equivalent overlay
- **AND** it preserves the current workflow and support context during that
  transition

### Requirement: Desktop GUI shell gives the active workflow a step-aware action hierarchy

The system SHALL structure the active desktop workflow around the next
meaningful operator decisions instead of front-loading every advanced or
support-oriented control at once.

#### Scenario: Primary editor emphasizes the next meaningful actions

- **GIVEN** the operator opens the active desktop workflow editor
- **WHEN** the shell renders the current workflow
- **THEN** the primary editor shows the current task title, concise guidance,
  and a clear action hierarchy for the next meaningful operator step
- **AND** the shell keeps one primary action visually dominant over secondary
  actions

#### Scenario: Advanced detail uses progressive disclosure

- **GIVEN** the active desktop workflow contains advanced runtime defaults,
  support notes, or secondary explanation
- **WHEN** the operator first opens that workflow
- **THEN** the shell keeps core inputs and primary actions above the fold
- **AND** advanced or support-only detail uses progressive disclosure instead of
  competing with the first read of the workflow

### Requirement: Desktop GUI shell keeps secondary libraries off the default screen

The system SHALL keep full saved-profile, managed-provider, preset, and
provider-family libraries off the default desktop first read unless the
operator explicitly opens them.

#### Scenario: Default desktop first read stays within one task

- **GIVEN** the desktop GUI shell is in a routine ready state
- **WHEN** the operator views the default first screen
- **THEN** the shell shows only the active task, compact readiness, and minimal
  task-switch context
- **AND** any persistent context lane stays orienting and compact instead of
  becoming a second scrollable library wall

#### Scenario: Operator enters a secondary library from the active workflow

- **GIVEN** the operator needs a preset, saved profile, managed provider, or
  provider family that is not part of the current first read
- **WHEN** the operator invokes the relevant explicit library action
- **THEN** the shell opens that library as a secondary surface with a clear
  return path
- **AND** the first-screen workflow remains the default landing surface after
  the operator exits that library

### Requirement: Desktop GUI offers explicit preset bootstrap entry surfaces

The system SHALL let the desktop GUI offer preset bootstrap through explicit
task-start surfaces that seed managed provider drafts or records instead of
relying on always-visible preset cards beside the active editor.

#### Scenario: Desktop bootstrap uses an available preset from an explicit entry surface

- **GIVEN** a desktop preset for a shipped supported provider family
- **WHEN** the operator opens the preset bootstrap surface and chooses the
  `VK`, `WB Stream`, or `RTK Smarthome` preset
- **THEN** the GUI seeds a new managed provider draft or record for that
  provider family
- **AND** the preset does not pretend to be a separate provider identity
- **AND** the operator can continue through the active workflow without keeping
  the entire preset catalog permanently visible

#### Scenario: Desktop keeps unavailable presets explicit inside the bootstrap surface

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the operator opens the explicit preset bootstrap surface
- **THEN** the desktop shell does not show a preset for that unsupported
  provider family
- **AND** it does not imply support through placeholder cards

### Requirement: Desktop GUI shell uses canvas-routed secondary task surfaces

The system SHALL route saved-profile browsing, preset bootstrap,
managed-provider browsing, and provider-family selection through dedicated
main-canvas task surfaces instead of relying on modal-first overlays or
persistent companion cards.

#### Scenario: Operator opens a library or chooser from the active workflow

- **GIVEN** the operator is in an active desktop workflow
- **WHEN** the operator chooses saved profiles, presets, managed providers, or
  provider families
- **THEN** the shell opens that surface inside the main canvas as a dedicated
  route with an explicit back path
- **AND** the shell does not require a modal overlay as the primary interaction
  model for that flow

#### Scenario: Operator returns from a canvas-routed chooser without losing work

- **GIVEN** the operator has an in-progress draft or selected entity in the
  active desktop workflow
- **WHEN** the operator exits a canvas-routed chooser without applying a new
  selection
- **THEN** the shell returns to the prior editor route
- **AND** it preserves the draft and active selection state

#### Scenario: Canvas-routed chooser exposes an explicit in-canvas return path

- **GIVEN** a saved-profile, preset, managed-provider, or provider-family
  chooser is active in the main canvas
- **WHEN** the operator views that chooser route
- **THEN** the route exposes its own title and explicit back affordance inside
  the main canvas
- **AND** using that back affordance returns to the prior workflow route
  without relying on modal dismissal as the primary interaction model

### Requirement: Desktop GUI shell avoids duplicated task summaries around the active canvas

The system SHALL avoid persistent summary cards or companion panes that restate
the same entity or task already open in the main canvas.

#### Scenario: Active profile editor is open

- **GIVEN** the profile editor route is active in the desktop shell
- **WHEN** the operator views the full shell layout
- **THEN** the shell does not render separate persistent summary cards or
  route-restating action cards for that same profile or draft beside or above
  the editor
- **AND** the left pad stays compact and command-oriented

#### Scenario: Active managed-provider editor is open

- **GIVEN** the managed-provider editor route is active in the desktop shell
- **WHEN** the operator views the full shell layout
- **THEN** the shell does not render a second persistent companion surface or
  route-restating action card that repeats the same record context through
  stacked cards beside or above the editor
- **AND** the main canvas remains the only substantive detail surface for that
  task

#### Scenario: Routine ready shell avoids multi-region card dashboards

- **GIVEN** the desktop GUI shell is in a routine ready state on a desktop-width
  window
- **WHEN** the operator views the first screen without opening diagnostics or
  live work
- **THEN** the screen reads as `left pad + one dominant canvas + optional
  inspector`
- **AND** the default ready layout does not read as multiple equal-weight card
  regions competing for the operator's first attention

### Requirement: Desktop GUI shell supports explicit portable profile transfer

The system SHALL let the desktop shell explicitly export and import saved
profiles through the shared portable-profile envelope instead of relying on
ordinary shell-state files or runtime handoff export.

#### Scenario: Desktop exports a saved profile through file/text and QR-ready transfer

- **GIVEN** a saved profile in the desktop shell
- **WHEN** the operator chooses profile export
- **THEN** the desktop shell can produce the shared portable-profile envelope
  for supported file or text transfer paths
- **AND** it can present an operator-visible QR transfer surface from that same
  envelope when the payload fits the supported QR bounds
- **AND** if the payload does not fit those QR bounds, the shell fails closed
  for QR and keeps non-QR export available instead of truncating the payload

#### Scenario: Desktop imports a portable profile into the Profiles workspace

- **GIVEN** the operator provides a valid portable-profile envelope through a
  supported desktop import path such as file import or pasted envelope text
- **WHEN** the desktop shell accepts that import
- **THEN** it first shows a preview and explicit confirmation surface for the
  imported profile
- **AND** after operator confirmation it creates a local imported profile in
  the Profiles workspace
- **AND** it restores managed-provider mode when the envelope includes the
  required managed-provider snapshot
- **AND** it allocates fresh local ids for the imported profile and imported
  managed-provider snapshot
- **AND** it does not auto-resolve, auto-start runtime, or silently overwrite
  an existing local profile

#### Scenario: Desktop keeps secret-bearing profile transfer explicit

- **GIVEN** a portable profile export or import whose envelope is marked as
  secret-bearing
- **WHEN** the desktop shell presents that transfer action
- **THEN** it surfaces that sensitivity to the operator before completing the
  transfer
- **AND** it does not generate or persist that portable envelope as part of
  ordinary background shell state

### Requirement: Desktop GUI shell localizes shell-owned operator copy

The system SHALL localize desktop shell-owned operator copy and select the
active locale from device defaults plus an explicit shell-local operator
override.

#### Scenario: Desktop boot picks persisted override or device locale

- **GIVEN** the desktop GUI shell launches on a workstation with a preferred
  locale
- **WHEN** no shell-local locale override has been saved
- **THEN** the app uses the supported device locale or the documented default
  locale when the device locale is unsupported
- **AND** when a shell-local locale override exists the app restores that
  override on launch
- **AND** locale preference remains desktop-shell-local instead of becoming a
  host-global runtime setting
- **AND** the desktop app root resolves framework localization delegates,
  supported locales, and the localized app title from the shared shell
  localization package instead of leaving framework chrome or title copy
  hardcoded in English

#### Scenario: Desktop falls back cleanly when localized host metadata is unavailable

- **GIVEN** the desktop shell renders provider or validation metadata from the
  local control plane
- **WHEN** localized display metadata for the active locale is unavailable
- **THEN** the desktop shell falls back to the base descriptor or message text
- **AND** shell-owned chrome such as actions, navigation, and empty states
  still renders in the active shell locale
- **AND** the desktop shell does not invent translations by parsing
  machine-readable ids, field keys, or violation codes

#### Scenario: Desktop exposes locale override through compact shell chrome

- **GIVEN** an operator needs to override the workstation locale on desktop
- **WHEN** they use the first localized desktop shell slice
- **THEN** the locale switch is reachable through a compact shell menu or
  equivalent top-level shell chrome entry
- **AND** the first slice does not require a dedicated settings surface only to
  change locale

### Requirement: Desktop packaged shell uses canonical RelayDock desktop packaging identity

The system SHALL package the desktop shell with canonical RelayDock desktop
packaging identity on platforms that expose bundle or application identifiers
or bundled app output names instead of placeholder `gui_shell` identifier
families.

#### Scenario: Linux desktop runtime uses the canonical application identifier

- **GIVEN** a packaged Linux desktop build
- **WHEN** the app launches and integrates with the host desktop environment
- **THEN** the GTK application identifier and related desktop-integration
  metadata use the canonical RelayDock desktop identifier
- **AND** the published Linux build does not keep `com.defin85.gui_shell` or
  the legacy `gui_shell` desktop shell stem as its supported packaged desktop
  identity

#### Scenario: macOS bundle uses the canonical desktop bundle identifier

- **GIVEN** the repo-owned macOS desktop build metadata and bundled app output
- **WHEN** the Runner app bundle is packaged or signed
- **THEN** the main bundle, related test targets, and bundled app output
  derive from the canonical RelayDock desktop identity
- **AND** the published desktop app does not keep example or placeholder
  bundle identifiers such as `com.example.guiShell` or legacy shell output
  names such as `gui_shell.app`

