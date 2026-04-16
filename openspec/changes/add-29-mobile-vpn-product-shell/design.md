## Context

The repository now has a real Android `VpnService` path, but the current mobile
shell still behaves like an operator console:

- the root screen is `Workflow / Activity / Diagnostics`
- profile drafting and provider configuration dominate the home surface
- diagnostics remain too close to the first-screen workflow

That shape was reasonable before the Android VPN path was real, but it is the
wrong default once the app can actually start and stop a product VPN session.

The benchmark apps reviewed for this change show four recurring patterns:

- OpenVPN keeps a full operator UI but also exposes a much simpler minimal
  connect surface for the common path.
- Hiddify centers the home view on active profile plus one dominant connection
  action and pushes advanced surfaces behind secondary navigation.
- v2rayNG keeps a simple Android main screen with one floating start or stop
  control and moves per-app proxy into a separate searchable screen.
- v2rayN is dense and operator-friendly on desktop, which is useful as a
  contrast but not a good model for our primary mobile home.

## Goals / Non-Goals

- Goals:
  - Make the primary mobile shell feel like a VPN app instead of a support
    console.
  - Keep one dominant start or disconnect action on the home surface.
  - Separate `Home`, `Profiles`, `Routing`, and support-oriented activity or
    diagnostics flows.
  - Preserve honest scope presentation for `android_vpn_service` and future
    non-system Android modes.
- Non-Goals:
  - Do not redesign desktop UI in this change.
  - Do not invent new runtime semantics beyond what the host already exposes.
  - Do not hide diagnostics completely; they remain available as support
    surfaces.
  - Do not blur `android_vpn_service` and future proxy-only or non-system
    modes into one ambiguous workflow.

## Decisions

### Decision: Mobile home becomes VPN-first

The first-class phone-sized destination will show:

- selected profile or empty state
- runtime mode and scope summary
- one dominant start or disconnect action
- compact live status and a drill-down into activity

It will no longer be dominated by inline profile and provider editors.

### Decision: Profiles are primary, routing is dedicated but mode-aware

Saved profiles and add/import flows are first-class product navigation
surfaces.
App-routing selection is still a dedicated surface, but on compact phones it
should stay behind explicit navigation from home or profiles instead of being a
permanently promoted top-level tab.

This follows the pattern seen in Hiddify and v2rayNG, keeps the home screen
short enough for ordinary operators, and avoids implying that every Android
mode exposes per-app routing.

On wider tablet layouts, the shell may promote `Routing` into the
`NavigationRail`, but only when the currently selected mode actually supports
app-routing.

### Decision: Diagnostics stay explicit but secondary

Logs, raw events, diagnostic bundles, and support-first controls remain part of
the shell, but they are reached through secondary destinations or drill-down
links from the home surface.

The primary home does not inline raw event panels, export controls, or large
diagnostic matrices by default.

### Decision: Compact phones collapse support into one destination

On compact phone layouts, activity and diagnostics should share one explicit
support destination with internal segments, tabs, or drill-down routes instead
of consuming multiple peer top-level tabs.

Wider layouts may expose support sub-surfaces more directly, but compact
navigation should reserve first-class prominence for the product workflow.

### Decision: Runtime mode and scope stay explicit on home

The home surface must describe whether the app is using:

- Android system VPN (`android_vpn_service`)
- all apps vs selected apps scope
- a future non-system Android mode

That copy is product-critical because Android system VPN and future proxy-only
or relay modes do not have the same user expectations or detection surface.

### Decision: Primary tunnel control stays on home

The fastest connect or disconnect action stays on `Home` across phone and
tablet layouts.

Support surfaces may show runtime details, failures, and drill-down actions,
but operators should not need to enter support just to toggle the VPN state.

### Decision: Minimal user workflow and operator workflow coexist

This change does not remove the operator shell. Instead, it demotes it:

- product home is for ordinary connect/disconnect use
- support surfaces remain available for activity inspection and diagnostics

This mirrors the useful part of the OpenVPN split between a fuller operator UI
and a minimal connect-oriented path.

## Risks / Trade-offs

- Moving profile editing off the current home screen adds one navigation step
  for advanced operators.
  Mitigation: keep fast entry points from home to profile and routing surfaces.
- A more product-like home can accidentally hide important typed failures.
  Mitigation: keep compact failure summaries on home and one-tap drill-down
  into activity and diagnostics.
- Future proxy-only mode work could be forced into a system-VPN-shaped shell if
  this change is too Android-VPN-specific.
  Mitigation: keep the shell shape mode-aware and keep scope copy explicit.

## Migration Plan

1. Rework mobile information architecture around dedicated destinations.
2. Replace the current diagnostics-heavy home with a VPN-first home.
3. Move profile management and per-app routing into dedicated screens.
4. Collapse compact support navigation into one explicit support destination
   while keeping activity/diagnostics drill-down intact.
5. Keep support surfaces reachable and verify typed failure visibility.
6. Validate the new shell on phone-sized layouts, then verify preserved state
   across wider mobile/tablet breakpoints before widening the design.

## Open Questions

- When a generic support affordance opens the support workflow, whether the
  initial sub-surface should stay pinned to `Activity` or remember the last
  support view used by the operator.
