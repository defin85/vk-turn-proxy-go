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

The system SHALL provide mobile-first template bootstrap entry points that
combine read-only shipped templates with shell-owned user templates, while
keeping the top-level `Providers` destination focused on saved providers rather
than a template catalog.

#### Scenario: Mobile distinguishes user templates from shipped templates

- **GIVEN** the mobile shell has one or more user templates and one or more
  shipped templates
- **WHEN** the operator opens the template picker from the new-provider flow
- **THEN** the UI keeps `My templates` distinct from shipped templates
- **AND** search or filtering does not erase that distinction

#### Scenario: Mobile keeps shipped templates read-only

- **GIVEN** a shipped template in the mobile template picker
- **WHEN** the operator inspects it
- **THEN** the shell allows using that template as a seed
- **AND** it does not offer edit or delete actions for that shipped template

#### Scenario: Mobile keeps unavailable shipped templates explicit

- **GIVEN** a provider family that is not intentionally shipped in the
  app-owned supported-provider catalog
- **WHEN** the operator opens the mobile template picker
- **THEN** it does not show a shipped template for that unsupported provider
  family
- **AND** it does not imply support through placeholder template cards

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

The system SHALL present the mobile GUI shell through a VPN-first product
workflow instead of a diagnostics-heavy stacked dashboard.

#### Scenario: Operator opens the mobile shell on a phone-sized layout

- **GIVEN** the mobile GUI shell starts on a phone-sized layout
- **WHEN** the operator lands on the primary app surface
- **THEN** the first-class mobile view focuses on the current VPN workflow,
  including selected profile or empty state, runtime mode, scope summary, and
  a primary start or disconnect action
- **AND** activity, logs, and diagnostics are not the dominant first-screen
  payload

#### Scenario: Operator moves between primary destinations

- **GIVEN** the mobile GUI shell exposes multiple primary workflow
  surfaces
- **WHEN** the operator navigates between home and the dedicated profile,
  routing, and support surfaces
- **THEN** the shell preserves selected profile and current workflow context
- **AND** it does not force the operator back into one large stacked dashboard
  just to reach another part of the mobile workflow

#### Scenario: Wider layout promotes routing only when the current mode supports it

- **GIVEN** the mobile GUI shell is running on a wider mobile or tablet layout
- **AND** the current mobile mode supports per-app routing
- **WHEN** the shell renders its primary navigation
- **THEN** it may expose `Routing` as a dedicated rail destination
- **AND** modes that do not support app-routing do not receive a misleading
  first-class routing destination

### Requirement: Mobile GUI shell uses progressive disclosure for advanced and secondary actions

The system SHALL use progressive disclosure for advanced runtime controls,
diagnostics, raw events, and secondary resolution or session actions on
mobile-sized screens.

#### Scenario: Home surface has advanced support actions available

- **GIVEN** the operator is on the primary mobile home surface
- **WHEN** the app has diagnostics, raw events, or support-oriented actions
  available
- **THEN** those actions remain behind explicit support affordances or
  drill-down routes
- **AND** the home surface stays focused on connection state and primary
  connection actions

#### Scenario: Profile contains advanced runtime overrides

- **GIVEN** the operator is editing a mobile profile that includes advanced
  runtime overrides or verbose provider guidance
- **WHEN** the profile editor first appears
- **THEN** the primary inputs and primary actions remain immediately visible
- **AND** advanced or support-oriented content stays behind explicit disclosure

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

### Requirement: Mobile GUI remains a typed consumer of Android VPN startup

The system SHALL keep the mobile GUI shell as a typed consumer of packaged-host
Android VPN startup rather than the owner of Android VPN primitives.

#### Scenario: Mobile GUI renders Android VPN workflow without owning `VpnService`

- **GIVEN** a production Android package whose packaged host reports the
  documented `android_vpn_service` mode
- **WHEN** the operator inspects or starts that mode from the mobile GUI
- **THEN** the UI renders capability, app-scope choice, and typed startup
  result state from the packaged host
- **AND** it does not implement its own direct `VpnService` lifecycle or
  Android route-application logic

### Requirement: Mobile GUI keeps system-tunnel UX adapter-driven rather than Android-API-driven

The system SHALL keep system-tunnel UX in the mobile shell tied to host-reported
mode metadata and typed startup results instead of Android API naming.

#### Scenario: Future mobile system-tunnel mode reuses the shell role

- **GIVEN** a future packaged mobile host that reports a different system-tunnel
  adapter from Android `VpnService`
- **WHEN** the mobile GUI renders that later mode
- **THEN** the shell can keep the same typed consumer role for capability,
  scope, and startup state
- **AND** it does not require a second UI architecture just because the native
  adapter is no longer Android-specific

### Requirement: Mobile GUI shell presents a VPN-first home surface

The system SHALL provide a mobile home surface that behaves like a product VPN
entry point instead of an inline operator console.

#### Scenario: Operator has a selected profile and no active tunnel

- **GIVEN** the operator has at least one saved profile
- **AND** the app has no active mobile tunnel
- **WHEN** the operator opens the home surface
- **THEN** the shell shows the selected profile, current runtime mode, and
  scope summary
- **AND** it presents one dominant start action for the current mobile mode

#### Scenario: Operator has an active tunnel

- **GIVEN** the app has an active mobile tunnel or ready platform tunnel
- **WHEN** the operator opens the home surface
- **THEN** the shell presents one dominant disconnect action
- **AND** it shows compact live status rather than forcing immediate navigation
  into diagnostics

#### Scenario: Operator has no saved profiles

- **GIVEN** the app has no saved profiles
- **WHEN** the operator opens the home surface
- **THEN** the shell presents a clear empty state
- **AND** the primary actions are to add or import a profile rather than to
  browse diagnostics-first UI

### Requirement: Mobile GUI shell separates profile management from the home surface

The system SHALL keep saved profile management in its own dedicated mobile
surface instead of making profile editing the dominant payload on the home
screen.

#### Scenario: Operator opens the profile destination

- **GIVEN** the operator needs to browse or manage saved profiles
- **WHEN** they navigate to the profile destination
- **THEN** the shell shows the saved profile list plus explicit add and import
  entry points
- **AND** profile management does not depend on first opening a diagnostics or
  support route

#### Scenario: Operator edits a profile and returns home

- **GIVEN** the operator edits or selects a profile from the profile
  destination
- **WHEN** they return to the home surface
- **THEN** the selected profile and updated product context are reflected on
  home
- **AND** the home surface remains focused on connection state instead of
  reopening a full inline editor by default

### Requirement: Mobile GUI shell gives per-app routing its own destination

The system SHALL provide per-app routing through a dedicated mobile routing
surface instead of an inline home or diagnostics widget.

#### Scenario: Operator manages selected-app scope

- **GIVEN** the current mobile mode supports per-app routing or selected-app
  scope
- **WHEN** the operator opens the routing surface
- **THEN** the shell shows explicit scope semantics such as all apps,
  included apps, or excluded apps
- **AND** the app list is searchable on mobile-sized layouts

#### Scenario: Home references routing without embedding the full list

- **GIVEN** the current mobile mode uses selected-app scope
- **WHEN** the operator views the home surface
- **THEN** the shell shows a compact routing summary
- **AND** the detailed package list remains in the dedicated routing surface

#### Scenario: Current mode does not expose app routing

- **GIVEN** the selected mobile mode does not support per-app routing or
  selected-app scope
- **WHEN** the operator views home or profile-related surfaces
- **THEN** the shell does not present routing as if it were an available
  primary workflow path
- **AND** any routing affordance remains hidden or explicitly disabled with
  mode-specific explanation

### Requirement: Mobile GUI shell presents runtime mode and scope honestly on the home surface

The system SHALL describe the current mobile runtime mode and user-visible
scope explicitly instead of implying that all Android execution modes behave
the same way.

#### Scenario: Current mode is Android system VPN

- **GIVEN** the shell is presenting `android_vpn_service`
- **WHEN** the operator views the current mode on home
- **THEN** the shell labels it as a system VPN mode
- **AND** it distinguishes all-apps scope from selected-app scope in plain
  operator-facing copy

#### Scenario: Future non-system Android mode is available

- **GIVEN** a future Android non-system execution mode becomes available
- **WHEN** the shell presents that mode on mobile
- **THEN** it uses distinct scope and mode copy from `android_vpn_service`
- **AND** it does not present both modes as if they had the same reach or
  semantics

### Requirement: Mobile GUI shell keeps diagnostics and activity as secondary support surfaces

The system SHALL keep activity, logs, diagnostics, and support actions
available without making them the dominant first impression of the mobile app.

#### Scenario: Operator needs live runtime details

- **GIVEN** the operator is on the home surface
- **WHEN** they need sessions, resolutions, logs, or diagnostics
- **THEN** the shell provides an explicit drill-down into support-oriented
  activity or diagnostics surfaces
- **AND** returning from those surfaces preserves the primary home context

#### Scenario: Support workflow does not own the primary VPN toggle

- **GIVEN** the operator needs a fast start or disconnect action
- **WHEN** they are using the mobile shell on phone or tablet
- **THEN** the primary VPN toggle remains on the home surface
- **AND** support surfaces focus on runtime details, failures, logs, and
  diagnostics instead of becoming the required place to toggle VPN state

#### Scenario: Compact phone layout opens support workflows

- **GIVEN** the mobile shell is running on a compact phone-sized layout
- **WHEN** the operator opens the explicit support destination from home
- **THEN** activity and diagnostics stay within that support workflow instead
  of consuming multiple peer top-level tabs
- **AND** the home surface retains first-class prominence for connection
  status and primary connection actions

#### Scenario: Home avoids raw support controls by default

- **GIVEN** the app can export diagnostics or show raw event feeds
- **WHEN** the operator lands on home
- **THEN** the shell does not render those raw support controls inline as the
  default first-screen payload
- **AND** those controls remain available in secondary support surfaces

### Requirement: Mobile GUI shell supports explicit portable profile transfer with QR and platform-native share/import paths

The system SHALL let the mobile shell explicitly export and import saved
profiles through the shared portable-profile envelope using mobile-native share,
file, and QR workflows.

#### Scenario: Mobile keeps app-local Android and iOS transfer adapters over one shared envelope

- **GIVEN** the mobile shell supports portable profile transfer on more than
  one mobile platform
- **WHEN** it exposes share, file, or QR transfer actions
- **THEN** the mobile app keeps platform-specific Android and iOS adapter
  wiring app-local
- **AND** the shared portable-profile envelope, preview, and validation model
  remain platform-neutral

#### Scenario: Mobile exports a saved profile through QR or platform-native transfer

- **GIVEN** a saved profile in the mobile shell
- **WHEN** the operator chooses profile export
- **THEN** the mobile shell can render the shared portable-profile envelope as
  QR and expose platform-native share or file actions from that same envelope
- **AND** if the payload does not fit the supported QR bounds, the shell fails
  closed for QR and keeps non-QR transfer available instead of emitting a
  partial QR payload

#### Scenario: Mobile imports a portable profile from QR scan or supported file/share ingress

- **GIVEN** the operator scans a supported portable-profile QR or opens a valid
  portable-profile payload through a supported mobile file/share ingress path
- **WHEN** the mobile shell validates that envelope
- **THEN** it first shows a preview and explicit confirmation surface for the
  imported profile
- **AND** after operator confirmation it creates a local imported profile in
  the Profiles workflow
- **AND** it restores managed-provider mode when the envelope includes the
  required managed-provider snapshot
- **AND** it allocates fresh local ids for the imported profile and imported
  managed-provider snapshot
- **AND** it does not require shipped or user template records on the
  destination shell to restore that imported profile
- **AND** it does not auto-connect, auto-resolve, auto-launch browser
  continuation, or silently overwrite an existing local profile

#### Scenario: Mobile keeps secret-bearing profile transfer explicit

- **GIVEN** a portable profile export or import whose envelope is marked as
  secret-bearing
- **WHEN** the mobile shell presents that transfer action
- **THEN** it surfaces that sensitivity to the operator before completing the
  transfer
- **AND** it does not treat that envelope as ordinary persisted app state

### Requirement: Mobile shell exposes remembered embedded sign-in reset without full local-state wipe

The system SHALL let the operator clear remembered app-owned browser sign-in
state from the mobile shell through a dedicated embedded sign-in reset action,
without requiring app reinstall or a full local state reset.

#### Scenario: Operator clears remembered embedded sign-in from the mobile shell

- **GIVEN** the mobile shell previously remembered sign-in state for a
  compatible owned-browser continuation flow
- **WHEN** the operator invokes the documented embedded sign-in reset action
- **THEN** the mobile shell clears that app-owned browser session state
- **AND** a later owned-browser challenge starts from signed-out embedded
  browser state
- **AND** saved profiles, selected profile state, and ordinary shell
  preferences remain intact
- **AND** the operator does not need to invoke the broader local-state reset
  action to clear remembered embedded sign-in

### Requirement: Mobile GUI exposes a development local-network routing profile separately from app scope

The system SHALL present development-oriented local-network preservation as a
separate routing-profile choice instead of collapsing it into app-selection
scope or a different Android runtime mode.

#### Scenario: Routing surface offers the development Wi-Fi profile

- **GIVEN** the connected Android host advertises support for the typed
  underlay-route policy `preserve_active_local_network`
- **WHEN** the operator opens the mobile routing surface
- **THEN** the UI presents a separate development-oriented routing profile such
  as `Development Wi-Fi`
- **AND** the profile is described as preserving the active local network while
  the Android system VPN remains active
- **AND** that choice stays separate from `all apps`, `included apps`, and
  `excluded apps` scope selection

#### Scenario: Unsupported host does not show a misleading development profile

- **GIVEN** the connected host does not advertise development local-network
  preservation for the current Android VPN mode
- **WHEN** the operator opens the routing surface
- **THEN** the mobile shell does not present `Development Wi-Fi` as if it were
  available
- **AND** it does not imply that ordinary app-routing scope already preserves
  the local debug path

#### Scenario: Operator changes the development local-network profile

- **GIVEN** the operator changes the underlay-route profile for the active
  Android VPN mode
- **WHEN** the shell applies that change
- **THEN** the shell treats it as a VPN startup preference that requires a
  restart to take effect
- **AND** it does not silently pretend that the active tunnel was mutated in
  place

#### Scenario: Operator updates visible app flags in bulk

- **GIVEN** the operator is using `included apps` or `excluded apps` scope on
  the mobile routing surface
- **AND** the app list is filtered by the current search query
- **WHEN** the operator applies a bulk select or bulk clear action
- **THEN** the shell updates the flags for the currently visible app set in one
  action
- **AND** it does not silently mutate apps that are outside the current
  filtered result set

### Requirement: Mobile GUI shell localizes shell-owned operator copy

The system SHALL localize mobile shell-owned operator copy and select the
active locale from device defaults plus an explicit shell-local operator
override.

#### Scenario: Mobile boot picks persisted override or device locale

- **GIVEN** the mobile GUI shell launches on a device with a preferred locale
- **WHEN** no shell-local locale override has been saved
- **THEN** the app uses the supported device locale or the documented default
  locale when the device locale is unsupported
- **AND** when a shell-local locale override exists the app restores that
  override on launch
- **AND** locale preference remains mobile-shell-local instead of becoming a
  host-global runtime setting
- **AND** the mobile app root resolves framework localization delegates,
  supported locales, and the localized app title from the shared shell
  localization package instead of leaving framework chrome or title copy
  hardcoded in English

#### Scenario: Mobile falls back cleanly when localized host metadata is unavailable

- **GIVEN** the mobile shell renders provider or validation metadata from the
  local control plane
- **WHEN** localized display metadata for the active locale is unavailable
- **THEN** the mobile shell falls back to the base descriptor or message text
- **AND** shell-owned chrome such as actions, navigation, and empty states
  still renders in the active shell locale
- **AND** the mobile shell does not invent translations by parsing
  machine-readable ids, field keys, or violation codes

#### Scenario: Mobile exposes locale override through compact shell chrome

- **GIVEN** an operator needs to override the device locale on mobile
- **WHEN** they use the first localized mobile shell slice
- **THEN** the locale switch is reachable through a compact shell menu or
  equivalent top-level shell chrome entry
- **AND** the first slice does not require a dedicated settings surface only to
  change locale

### Requirement: Mobile GUI shell uses task-aligned interaction surfaces

The system SHALL choose mobile interaction surfaces by task weight and content
depth instead of mixing centered dialogs, bottom sheets, and follow-on routes
for equivalent jobs.

#### Scenario: Operator changes a local routing parameter

- **GIVEN** the operator is already on a mobile workflow screen such as
  `Routing`
- **WHEN** they choose a local reversible parameter such as `Routing profile`
  or `App scope`
- **THEN** the shell presents that choice in a bottom sheet anchored to the
  current workflow
- **AND** dismissing the picker returns the operator to the same screen without
  entering a separate library-style flow

#### Scenario: Operator starts a catalog-style provider creation flow

- **GIVEN** the operator starts a mobile provider creation flow that includes
  provider families, templates, search, or multiple actions
- **WHEN** the shell opens that chooser
- **THEN** it presents the chooser as a dedicated follow-on mobile surface
  instead of a centered dialog
- **AND** that surface uses ordinary mobile back navigation
- **AND** it can scale to long lists or search without crowding the root
  workflow surface

#### Scenario: Operator opens a compact preview, confirmation, or status summary

- **GIVEN** the shell needs to show a compact preview, confirmation, or short
  contextual status summary
- **WHEN** that content does not require library-style browsing or multi-step
  navigation
- **THEN** the shell may present it as a dialog-sized overlay
- **AND** that overlay does not become the primary container for search-heavy,
  tabbed, or catalog-style flows

### Requirement: Mobile GUI exposes first-class root actions for profiles

The system SHALL expose profile management and portable-profile transfer actions
from the primary `Profiles` workflow surface instead of hiding them behind
profile creation or editor-only disclosure.

#### Scenario: Profiles root exposes import and export directly

- **GIVEN** the operator is on the mobile `Profiles` workflow root
- **WHEN** they need to import a profile or export a saved profile
- **THEN** the shell exposes explicit root-level profile import and saved-profile
  export actions from that `Profiles` surface
- **AND** importing a profile does not require opening `Add profile` first
- **AND** exporting a profile does not require navigating into the profile
  editor footer or disclosure sections first

#### Scenario: Profiles root exposes record actions for the focused profile

- **GIVEN** a focused saved profile on the `Profiles` workflow surface
- **WHEN** the operator inspects that root entity surface
- **THEN** the shell exposes a selection-aware root action row for `Edit`,
  `Copy`, `Delete`, and `Make current`
- **AND** those actions are discoverable without forcing the operator to hunt
  through editor-only overflow menus
- **AND** the shell does not duplicate that same record-action cluster in a
  second detail-header surface

### Requirement: Mobile GUI keeps current-profile targeting separate from detail navigation

The system SHALL keep opening a saved profile for inspection or editing
separate from making that profile the current `Home` target.

#### Scenario: Opening a profile does not implicitly retarget Home

- **GIVEN** the mobile shell contains more than one saved profile
- **WHEN** the operator opens a profile from the `Profiles` list for detail or
  editing
- **THEN** the shell opens or focuses that profile detail surface
- **AND** the current profile used by `Home` remains unchanged until the
  operator explicitly chooses the make-current action

#### Scenario: Restored shell state keeps current profile separate from focused detail

- **GIVEN** the operator last used one profile as the current `Home` target and
  a different profile as the focused detail or editing context
- **WHEN** the mobile shell restores local shell state after restart
- **THEN** it restores those two contexts separately
- **AND** it does not silently collapse them back into one implicit selection

### Requirement: Mobile GUI exposes first-class root actions for providers and templates

The system SHALL expose managed-provider and user-template actions from the
primary `Providers` workflow surface instead of leaving those actions buried in
provider editors or create-only flows.

#### Scenario: Providers root exposes reusable-record actions

- **GIVEN** one or more saved managed providers exist in mobile shell state
- **WHEN** the operator opens the `Providers` workflow
- **THEN** the shell exposes `New provider` from the root command surface and a
  selection-aware root action row for `Copy`, `Use in profile`,
  `Save as template`, `Edit`, and `Delete`
- **AND** the operator does not need to open the provider editor just to
  discover those reusable-record actions

#### Scenario: Templates are first-class in the Providers workflow

- **GIVEN** the shell supports user templates and shipped presets
- **WHEN** the operator opens the `Providers` workflow
- **THEN** templates are reachable as a first-class `Providers` surface instead
  of only through the create-provider chooser
- **AND** user-template actions such as `Use`, `Copy`, `Edit`, and `Delete`
  are visible from that template surface
- **AND** those focused-template actions use the same selection-aware root-row
  pattern rather than a second detail-header cluster
- **AND** shipped presets remain part of the provider-create bootstrap flow
  rather than becoming a second editable template-management surface

### Requirement: Mobile GUI offers explicit duplicate semantics for reusable entities

The system SHALL let the operator duplicate saved profiles, managed providers,
and user templates without mutating the source record.

#### Scenario: Duplicating a profile creates a new draft

- **GIVEN** a saved profile exists in the mobile shell
- **WHEN** the operator chooses `Copy` for that profile
- **THEN** the shell creates a new unsaved profile draft seeded by snapshot
  copy from the source profile
- **AND** the later saved copy receives a fresh local id
- **AND** the copy action does not auto-connect, auto-resolve, or auto-start a
  session

#### Scenario: Duplicating a provider or template preserves the source

- **GIVEN** a saved managed provider or user template exists
- **WHEN** the operator chooses `Copy` for that reusable record
- **THEN** the shell seeds a new draft or template record by snapshot copy
- **AND** editing the copied draft does not mutate the source record in place

### Requirement: Mobile editors keep secondary entity actions off the commit footer

The system SHALL keep profile, provider, and template editor footers focused on
commit actions while secondary entity-management actions live on root or detail
command surfaces.

#### Scenario: Profile editor footer stays focused

- **GIVEN** the operator is editing a mobile profile
- **WHEN** the profile editor first appears
- **THEN** the visible commit footer prioritizes save plus start-or-resolve
  actions
- **AND** secondary actions such as import, export, copy, and delete do not
  compete for the same footer slot

#### Scenario: Provider and template editors stay focused

- **GIVEN** the operator is editing a saved provider or template
- **WHEN** that editor surface appears
- **THEN** the visible commit footer stays limited to save-oriented workflow
  actions
- **AND** record-management helpers such as copy or delete remain available
  from the surrounding `Providers` workflow instead of overloading the editor
  footer

### Requirement: Mobile GUI keeps platform-tunnel activity aligned with sessions

The system SHALL present VPN-backed runtime activity through the same mobile
activity/session surface as other same-device runtime attempts instead of
forcing the operator to infer runtime state from VPN indicators or resolution
counts alone.

#### Scenario: Ready VPN-backed runtime appears in mobile activity

- **GIVEN** the operator starts a supported mobile platform-tunnel mode from
  the mobile shell
- **AND** the connected host reports `ready=true` for a runtime-backed startup
- **WHEN** the shell refreshes its activity surfaces
- **THEN** the corresponding runtime appears in the mobile `Sessions` surface
- **AND** the operator can reach ordinary session actions such as stop or
  diagnostics from that session entry
- **AND** the shell does not require the operator to treat `Resolutions` or a
  raw VPN indicator as the only proof that runtime exists

#### Scenario: Mobile shell selects the resulting runtime session after ready startup

- **GIVEN** the control plane returns a `session_id` for a successful mobile
  platform-tunnel startup or resume
- **WHEN** the shell completes that workflow
- **THEN** it refreshes the relevant mobile activity and support surfaces
- **AND** it may use that returned `session_id` to focus the resulting runtime
  entry without guessing from unrelated session updates

### Requirement: Mobile packaged shell uses the canonical RelayDock mobile identifier

The system SHALL package the production mobile shell under the canonical
RelayDock mobile package and bundle identifier family instead of legacy
`mobile_gui_shell` placeholder identities.

#### Scenario: Production Android package uses the canonical mobile application identifier

- **GIVEN** the repo-owned Android mobile packaging workflow
- **WHEN** the production mobile package is assembled
- **THEN** the Android `applicationId`, namespace, manifest-owned components,
  and package-oriented repo automation use the canonical RelayDock mobile
  identifier
- **AND** repo docs do not present `com.defin85.mobile_gui_shell` as the
  supported published package identity

#### Scenario: iOS mobile bundle uses the canonical mobile bundle identifier

- **GIVEN** the repo-owned iOS mobile build metadata
- **WHEN** the Runner bundle is packaged or signed
- **THEN** the main app and related test targets derive from the canonical
  RelayDock mobile bundle identifier
- **AND** the published mobile app does not keep placeholder bundle
  identifiers from the `mobileGuiShell` family

#### Scenario: Mobile publish-identity cutover does not hide state-migration limits

- **GIVEN** the supported mobile package or bundle identifier changes to the
  canonical RelayDock identity
- **WHEN** the operator follows the documented migration or install workflow
- **THEN** the workflow states explicitly whether shell-owned preferences and
  secure-storage contents are preserved or must be re-entered
- **AND** it does not present the identity cutover as a seamless in-place
  update unless a reviewed migration path is part of the supported workflow

### Requirement: Mobile GUI system tunnel support remains explicit and host-driven

The system SHALL keep mobile GUI system tunnel support explicit and host-driven instead of implying it from app installation alone.
Installing the mobile app SHALL NOT silently claim device-wide traffic capture support, but the app MAY offer a documented workflow for a later packaged host mode such as `android_vpn_service` when that host explicitly reports the mode as supported.

#### Scenario: Mobile app still lacks a supported platform tunnel mode

- **GIVEN** a mobile app install whose connected host does not report a supported later platform tunnel mode
- **WHEN** the operator inspects platform support in the app
- **THEN** the app reports that system tunnel support is not yet available for that target
- **AND** it does not silently claim device-wide traffic capture

#### Scenario: Packaged Android host reports a supported `android_vpn_service` mode

- **GIVEN** a production Android package whose packaged host reports `android_vpn_service` as a supported platform tunnel mode
- **WHEN** the operator inspects platform support in the mobile GUI shell
- **THEN** the app offers the documented Android system tunnel workflow for that mode
- **AND** it uses the typed startup result instead of guessing support from OS heuristics alone

### Requirement: Mobile GUI shell renders explicit Android app-scope policy

The system SHALL let the mobile GUI render the supported Android
`android_vpn_service` app-scope policy explicitly instead of implying that the
mode always captures all apps.

#### Scenario: Operator selects which apps the Android VPN mode should cover

- **GIVEN** a production Android package whose packaged host reports the
  documented `android_vpn_service` mode and its supported
  `application_routing_policy` values
- **WHEN** the operator enables Android system tunnel mode from the mobile GUI
- **THEN** the app can present the supported scope choices such as all apps or
  selected package sets
- **AND** it sends that scope choice through the typed host contract instead of
  reinterpreting package policy locally

#### Scenario: Mobile GUI does not present Android VPN mode as stealth

- **GIVEN** a production Android package whose packaged host reports a
  supported `android_vpn_service` mode
- **WHEN** the operator inspects or starts that mode in the mobile GUI
- **THEN** the app presents it as a documented Android system tunnel workflow
- **AND** it does not describe that mode as hidden from Android diagnostics or
  platform-visible VPN state

#### Scenario: Mobile GUI treats Android app-scope changes as reconnect-required

- **GIVEN** a production Android package whose packaged host reports a
  supported `android_vpn_service` mode
- **AND** the operator has already started that mode with one explicit
  app-scope selection
- **WHEN** the operator changes the requested app-scope policy or selected
  package set
- **THEN** the app treats that change as reconnect-required startup input
- **AND** it does not claim that the running Android VPN scope mutated in place

#### Scenario: Mobile GUI resumes Android startup after permission grant

- **GIVEN** a production Android package whose packaged host reports the
  documented `android_vpn_service` mode
- **AND** the host returned a resumable startup attempt waiting on Android VPN
  permission
- **WHEN** the operator grants that permission from the documented Android
  prompt
- **THEN** the app resumes that startup attempt through the canonical control
  plane
- **AND** it does not replace that flow with a separate shell-local Android VPN
  startup protocol

