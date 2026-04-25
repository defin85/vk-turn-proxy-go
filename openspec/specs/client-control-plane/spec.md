# client-control-plane Specification

## Purpose
Define the versioned local control-plane contract for profiles, sessions, challenges, diagnostics, event streaming, and capability negotiation.
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
plane so shells can discover runtime provider constraints without hard-coding
workflow logic to provider identifiers.

#### Scenario: Shell requests provider catalog from a compatible host

- **GIVEN** a compatible host with one or more supported providers
- **WHEN** a shell requests the provider catalog
- **THEN** the host returns typed descriptors for each advertised provider
- **AND** each descriptor includes the runtime metadata needed for validation,
  availability, browser policy, and provider-specific UX
- **AND** the shell may combine those descriptors with an app-owned supported
  provider catalog instead of treating the host descriptor list as its only
  operator-facing provider taxonomy

#### Scenario: App-owned shell workflow does not require provider-config capability

- **GIVEN** a host that advertises typed provider descriptors but does not
  expose `provider_configs` as a required capability
- **WHEN** a desktop or mobile shell negotiates for the app-owned provider
  workflow
- **THEN** the shell can still treat that host as compatible for ordinary
  managed-provider and profile workflows
- **AND** host-managed provider-config CRUD remains an optional compatibility
  surface rather than a required dependency

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

#### Scenario: Shell starts resolution from a managed-provider snapshot

- **GIVEN** a shell-managed provider record materialized into ordinary
  `provider`, `link`, and `provider_settings` values
- **WHEN** a shell starts resolution or session startup through the control
  plane
- **THEN** the host validates the resulting provider settings against the
  descriptor-declared schema for that provider
- **AND** the control-plane contract does not require a shell-managed provider
  identifier
- **AND** the host handles the materialized request the same way as an
  equivalent custom operator-entered request

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

### Requirement: Client control plane exposes typed challenge completion and browser-return metadata

The system SHALL expose machine-readable challenge completion, browser-return,
and owned-browser continuation metadata so shells can distinguish manual
confirmation, app-return-assisted continuation, and app-owned
browser-observed continuation without parsing provider text.
For app-return-assisted continuation, the challenge record SHALL also declare
the supported return-signal kinds for that challenge and whether one automatic
continue attempt is allowed.
For app-owned browser-observed continuation, the challenge record SHALL also
declare owned-browser cookie-scope metadata, and the continue contract SHALL
accept same-session embedded cookies and browser-observed request evidence from
that same owned-browser session.

#### Scenario: Challenge event advertises app-return-assisted continuation

- **GIVEN** a session whose provider challenge can resume through a documented mobile app-return path
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record includes a stable challenge identifier, a typed completion mode for app-return-assisted continuation, and typed return-signal metadata for that challenge
- **AND** the shell can determine that one automatic continue attempt is allowed without inferring behavior from prompt text or generic lifecycle heuristics alone

#### Scenario: Challenge event remains manual-only

- **GIVEN** a session whose provider challenge still requires explicit user confirmation after the browser step
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record keeps the same stable challenge identifier model
- **AND** it explicitly reports manual confirmation semantics instead of implying automatic resume support

#### Scenario: Challenge event advertises owned-browser-observed continuation

- **GIVEN** a session whose approved mobile provider challenge can continue inside one app-owned browser session
- **WHEN** the runtime surfaces that challenge through the control plane
- **THEN** the challenge record includes a stable challenge identifier, the `owned_browser_observed` completion mode, and owned-browser metadata with the cookie URL scope for that session
- **AND** the shell can open the approved app-owned browser path without inferring cookie scope from provider prompt text alone

#### Scenario: Owned-browser continuation accepts same-session observed evidence

- **GIVEN** an approved mobile provider challenge whose committed continuation contour depends on same-session browser-observed evidence
- **WHEN** the shell continues that challenge with a typed owned-browser payload captured from the same embedded session
- **THEN** the host accepts embedded cookies and browser-observed request evidence from that session through the control-plane contract
- **AND** approval does not depend on the challenge also exposing browser-owned replay requests

### Requirement: Client control plane negotiates runtime execution planning explicitly

The system SHALL advertise the runtime-execution-planning surface through an explicit host capability so updated shells can fail closed against hosts that still expose only artifact-family actions without typed execution plans.

#### Scenario: Updated shell negotiates against an older host

- **GIVEN** a shell build that expects typed runtime execution plans for host-owned same-device actions
- **WHEN** it negotiates with a host that does not implement the runtime-execution-planning surface
- **THEN** the host does not falsely claim that capability
- **AND** the shell can reject the host as incompatible before rendering plan-driven execution UX

### Requirement: Client control plane exposes typed runtime execution plans

The system SHALL expose typed runtime execution plans for supported host-owned same-device actions through the local control plane.

#### Scenario: Shell reads execution plans for a resolved artifact

- **GIVEN** a compatible host and a resolved artifact with one or more supported host-owned same-device actions
- **WHEN** a shell reads that artifact or requests its execution metadata through the control plane
- **THEN** the host returns the available runtime execution plans with explicit `access_method`, `carrier_family`, `engine_family`, optional `host_adapter`, and support-state metadata
- **AND** the shell does not need to recover those choices from provider-specific heuristics

#### Scenario: Shell requests an unavailable runtime execution plan

- **GIVEN** a resolved artifact and a host that exposes one or more runtime execution plans
- **WHEN** the shell requests startup through a plan that is unavailable, unsupported, or no longer valid for the current host build
- **THEN** the control plane fails explicitly before claiming readiness
- **AND** it identifies that requested execution plan as unavailable or unsupported
- **AND** it does not silently substitute another plan

### Requirement: Client control plane keeps strict WireGuard carrier material host-owned

The system SHALL let the host materialize and consume secret-bearing carrier
state for strict `turn_datagram` `wireguard_native` startup without serializing
that state through ordinary shell-facing control-plane reads.

#### Scenario: Host starts a strict WireGuard path without exporting the carrier lease

- **GIVEN** a resolved `generic_turn` artifact and a selected same-device
  execution plan with `carrier_family=turn_datagram` and
  `engine_family=wireguard_native`
- **WHEN** a shell requests same-device startup through the control plane
- **THEN** the host materializes and consumes any required strict WireGuard
  carrier state internally
- **AND** the control plane returns only typed session, resolution, or platform
  tunnel state
- **AND** the shell does not receive raw private keys, peer keys, or other
  startable carrier-secret material in ordinary API responses

#### Scenario: Host lacks the strict WireGuard materializer or carrier

- **GIVEN** a host build that can expose the requested platform adapter mode but
  does not implement the documented strict `turn_datagram` `wireguard_native`
  materializer or carrier
- **WHEN** a shell requests same-device startup through the control plane
- **THEN** the host fails explicitly before `ready=true`
- **AND** it reports the requested execution plan as unavailable or unsupported
- **AND** it does not silently fall back to the current overlay runtime

### Requirement: Client control plane remains the canonical Android VPN startup API

The system SHALL keep Android packaged VPN startup under the same versioned
client-control-plane contract instead of introducing a parallel Flutter-only or
Android-only startup protocol.

#### Scenario: Packaged Android build starts system tunnel through the control plane

- **GIVEN** a packaged Android build with the documented `android_vpn_service`
  path
- **WHEN** the mobile shell requests startup
- **THEN** it uses the versioned local control-plane contract as the canonical
  API surface
- **AND** the host coordinates any native Android adapter work behind that
  contract instead of exposing a second tunnel startup API to the shell
- **AND** any package-internal bridge to the Android adapter remains a
  host-internal implementation detail rather than a second shell-visible
  protocol

### Requirement: Shared startup semantics remain stage-oriented instead of Android-API-oriented

The system SHALL keep the packaged mobile system-tunnel boundary expressed in
typed startup stages and prerequisites instead of direct Android API objects or
method names.

#### Scenario: Shared control-plane contract is reused by a future mobile adapter

- **GIVEN** a future packaged mobile host that implements a different native
  adapter from Android `VpnService`
- **WHEN** that host reuses the packaged startup contract
- **THEN** the client-control-plane surface still uses typed stages,
  prerequisites, and ready/failure state
- **AND** it may cross a different native process or extension boundary than
  Android `VpnService`
- **AND** it does not require Flutter shells or the embedded Go host to speak
  Android-specific `VpnService` APIs directly

### Requirement: Client control plane exposes typed underlay-route policy support for platform tunnels

The system SHALL expose supported underlay-route policies through the local
control-plane contract so shells can request development-safe local-network
preservation without guessing host-specific behavior.

#### Scenario: Host advertises development underlay-route policy support

- **GIVEN** a compatible host that supports preserving the active local network
  for `android_vpn_service`
- **WHEN** a shell inspects the typed platform-tunnel capability metadata
- **THEN** the host advertises that underlay-route policy explicitly for that
  mode
- **AND** the shell does not need to infer support from package-routing fields
  or Android-version heuristics alone

#### Scenario: Shell starts a platform tunnel with a typed underlay-route policy

- **GIVEN** a shell requests platform tunnel startup through the local control
  plane
- **WHEN** it needs the development local-network-preserving profile
- **THEN** the startup request carries a typed `underlay_route_policy` value
- **AND** the host validates that value through the same versioned contract
  instead of treating it as an untyped Android-only hint

#### Scenario: Older or incompatible host lacks typed underlay-route policy support

- **GIVEN** a shell build that expects typed underlay-route policy support
- **WHEN** it negotiates with an older or incompatible host that does not
  advertise that capability
- **THEN** the shell can fail closed or suppress the unsupported workflow
  explicitly
- **AND** the control plane does not silently reinterpret the request as the
  default routing profile

### Requirement: Client control plane exposes locale-aware display metadata

The system SHALL let shells request locale-aware provider and validation
display metadata without changing stable machine-readable ids, field keys, or
violation codes.

#### Scenario: Shell requests provider catalog display metadata with locale preference

- **GIVEN** a compatible host and a shell with an active locale preference
- **WHEN** the shell requests provider catalog or provider-setting display
  metadata through the local control plane
- **THEN** the host may return localized provider names, provider
  descriptions, provider-setting labels, and provider-setting descriptions for
  the requested locale
- **AND** the stable provider identifiers and provider-setting keys remain
  unchanged for program logic
- **AND** the locale preference is carried with that metadata request or stream
  subscription instead of mutating a host-global locale flag shared by other
  shells

#### Scenario: Shell receives localized validation or availability messages

- **GIVEN** a host that validates provider settings or reports provider
  availability
- **WHEN** the host emits display-oriented availability or validation messages
- **THEN** the host may include localized display text that matches the
  shell-requested locale
- **AND** the stable machine-readable state and violation fields remain
  locale-neutral
- **AND** the shell does not need to recover action meaning from localized text
- **AND** localized display text does not become a cross-shell shared mutable
  state that forces one shell's locale onto another shell

#### Scenario: Older or untranslated hosts stay compatible

- **GIVEN** a shell that supports localized control-plane display metadata
- **WHEN** it connects to a host that returns only base display strings
- **THEN** the host remains compatible for the existing provider catalog and
  validation contracts
- **AND** the shell falls back to the base strings instead of rejecting the
  host or inventing translations from machine-readable identifiers

### Requirement: Client control plane publishes runtime-backed platform tunnels through ordinary sessions

The system SHALL expose any runtime-backed platform-tunnel startup that reaches
`ready=true` through the ordinary typed session surface instead of leaving that
runtime visible only through tunnel-specific state.

#### Scenario: Ready platform-tunnel startup creates a session

- **GIVEN** a local shell starts a supported platform-tunnel mode through the
  control plane
- **AND** that startup reaches `ready=true` after runtime attach succeeds
- **WHEN** the shell reads the resulting typed control-plane state
- **THEN** the control plane publishes an ordinary typed session record for
  that runtime
- **AND** the ready startup result includes the stable `session_id`
- **AND** the resulting session links back to the source resolution when the
  startup originated from a resolution-backed flow

#### Scenario: Startup fails before ready runtime attach

- **GIVEN** a local shell starts a supported platform-tunnel mode through the
  control plane
- **WHEN** startup fails during permission acquisition, route validation, host
  bring-up, or runtime attach
- **THEN** the control plane does not leave behind a misleading active session
  for that failed startup attempt
- **AND** the failure remains visible through the typed startup result and
  ordinary diagnostics or event surfaces

### Requirement: Client control plane accepts Android tunnel startup policy through the canonical contract

The system SHALL carry packaged Android `android_vpn_service` startup inputs
through the canonical versioned client-control-plane contract instead of
requiring Flutter shells to infer or apply Android package policy locally.

#### Scenario: Shell starts Android system tunnel with an explicit app-scope policy

- **GIVEN** a packaged Android host that advertises the documented
  `android_vpn_service` mode
- **WHEN** the mobile shell starts that mode with one supported
  `application_routing_policy` and any required selected package set
- **THEN** the startup request flows through the canonical control-plane
  contract
- **AND** the packaged host validates and applies that app-scope policy inside
  the Android host boundary
- **AND** the shell does not reinterpret or widen the package policy locally

#### Scenario: Shell requests an invalid Android app-scope policy

- **GIVEN** a packaged Android host starting `android_vpn_service`
- **WHEN** the shell sends a mixed, incomplete, or otherwise invalid
  `application_routing_policy` request through the control plane
- **THEN** the host returns a typed startup failure through that same contract
- **AND** the shell does not guess a fallback package policy outside the host

### Requirement: Android permission acquisition stays under the canonical control plane

The system SHALL surface Android VPN permission acquisition through the same
versioned client-control-plane startup contract instead of introducing a second
shell-visible Android tunnel protocol.

#### Scenario: Android startup requires VPN permission before host bring-up can continue

- **GIVEN** a packaged Android host starting the documented
  `android_vpn_service` path
- **WHEN** the host reaches the Android permission prerequisite before it can
  continue with route validation or runtime attach
- **THEN** the host reports that prerequisite through the canonical
  client-control-plane startup semantics
- **AND** the shell can drive the documented Android permission workflow
  without switching to a parallel shell-visible tunnel API
- **AND** any package-internal bridge to the Kotlin `VpnService` adapter
  remains a host-internal implementation detail

### Requirement: Android platform-tunnel startup is resumable after permission

The system SHALL model packaged Android `android_vpn_service` startup as a
resumable control-plane workflow when Android VPN permission must be granted by
the operator before host bring-up can continue.

#### Scenario: Host returns a resumable startup attempt for Android permission

- **GIVEN** a packaged Android host starting the documented
  `android_vpn_service` path
- **AND** the requested startup input already includes the selected
  `application_routing_policy`
- **WHEN** the host reaches the Android VPN permission prerequisite before it
  can continue startup
- **THEN** the host returns a typed startup result that reports the permission
  prerequisite
- **AND** it includes a stable startup attempt identifier for later resume
- **AND** the shell does not need to keep the original startup request open
  while the operator responds to the Android permission prompt

#### Scenario: Shell resumes Android startup after permission grant

- **GIVEN** a packaged Android host that previously returned a resumable
  Android startup attempt waiting on VPN permission
- **WHEN** the operator grants that permission and the shell resumes the
  documented startup attempt through the canonical control plane
- **THEN** the host continues that same startup flow with route validation,
  host bring-up, and runtime attach
- **AND** it returns the final typed ready or failure result through the same
  versioned control-plane contract

### Requirement: Client control plane remains the canonical packaged desktop tunnel startup API

The system SHALL keep packaged desktop tunnel startup under the same versioned
client-control-plane contract instead of introducing a parallel desktop-helper
startup protocol for shells.

#### Scenario: Packaged desktop build starts system tunnel through the control plane

- **GIVEN** a packaged desktop build with one documented system-tunnel mode
- **WHEN** the desktop shell requests startup
- **THEN** it uses the versioned local control-plane contract as the canonical
  API surface
- **AND** the host coordinates any native desktop adapter work behind that
  contract instead of exposing a second startup API to the shell

### Requirement: Shared desktop startup semantics remain stage-oriented instead of OS-API-oriented

The system SHALL keep the packaged desktop system-tunnel boundary expressed in
typed startup stages and prerequisites instead of direct Windows-, Linux-, or
Apple-specific API objects.

#### Scenario: Shared control-plane contract is reused by a future desktop adapter

- **GIVEN** a future packaged desktop host that implements a different native
  adapter from the first shipped desktop mode
- **WHEN** that host reuses the packaged startup contract
- **THEN** the client-control-plane surface still uses typed stages,
  prerequisites, and ready/failure state
- **AND** it does not require Flutter shells or the Go control plane to speak
  one OS adapter's APIs directly

