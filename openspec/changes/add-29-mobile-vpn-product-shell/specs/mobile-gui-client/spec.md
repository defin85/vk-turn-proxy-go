## MODIFIED Requirements
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

## ADDED Requirements
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
