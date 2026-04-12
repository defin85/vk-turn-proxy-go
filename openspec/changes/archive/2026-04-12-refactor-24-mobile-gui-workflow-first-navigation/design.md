## Context

The mobile shell already owns the right runtime boundaries:

- embedded host bridge
- secure local state
- browser handoff
- typed resolution/session state

The weak point is the screen model.

Today the app renders one scrolling dashboard with fixed-height sections for:

- host status
- platform-tunnel status
- notice banner
- profile editor
- resolutions
- sessions
- event stream

That structure keeps every feature visible, but it is still desktop-shaped.
On a phone, the operator usually needs one immediate path:

1. choose or edit a profile
2. resolve or start
3. inspect current activity only when needed

The current mobile shell also renders dense inline action groups in resolution
cards, which increases cognitive and tap complexity on smaller screens.

## Goals

- Make the mobile shell feel phone-native rather than dashboard-native
- Separate the primary profile/start flow from diagnostics and support surfaces
- Reduce inline action density on mobile cards
- Keep advanced runtime/tunnel details reachable without front-loading them
- Preserve current control-plane semantics and typed host reporting

## Non-Goals

- Change embedded-host, secure storage, or browser handoff ownership
- Claim new Android or iOS platform-tunnel support
- Remove resolutions, sessions, events, or diagnostics from the mobile shell
- Force desktop and mobile to share the same page composition

## Decisions

### Decision: Replace the stacked dashboard with top-level mobile navigation

The mobile shell should stop treating every surface as one vertically stacked
dashboard.

Instead, it should expose a small set of mobile-first destinations, such as:

- a primary home/workflow destination for profile selection, editing, resolve,
  and start
- an activity destination for resolutions and sessions
- a diagnostics destination for host state, tunnel detail, and event stream

The exact widget choice may vary, but the contract is multiple mobile
destinations or drill-downs, not one fixed-height dashboard page.

### Decision: Keep the home screen focused on the common path

The first screen should emphasize:

1. profile selection or creation
2. provider input
3. save / resolve / start

Advanced runtime overrides, verbose provider guidance, and support-only details
should move behind explicit disclosure so they do not crowd the initial mobile
screen.

### Decision: Reduce action density in resolution and session surfaces

Mobile cards should not expose every supported action as the same inline button
row by default.

The mobile shell should present:

- one context-appropriate primary action
- compact secondary affordances
- overflow or bottom-sheet access to the rest

This preserves capability coverage while making the mobile shell easier to scan
and operate one-handed.

### Decision: Summarize host and tunnel state before showing full diagnostics

The app still needs explicit fail-closed reporting, but the first mobile screen
should use a compact summary rather than a stack of large operational cards.

Detailed host and tunnel explanation remains available in diagnostics and in
blocked/error states.

## Alternatives Considered

### Keep the current screen and only shorten copy

Rejected.
The biggest problem is not copy length; it is the monolithic dashboard shape
and action density.

### Hide activity and diagnostics completely until later

Rejected.
Operators still need typed runtime feedback on mobile, especially during
challenge and startup flows.

### Mirror the future desktop refactor one-to-one

Rejected.
Mobile needs navigation and disclosure patterns that match smaller screens,
not a narrow copy of desktop rails and panels.

## Risks / Trade-offs

- Splitting one dashboard into several destinations can create state handoff
  bugs across tabs/routes.
- More progressive disclosure can hide secondary actions too aggressively if the
  defaults are not chosen carefully.
- Tests that assume one-page composition will need meaningful rewrites instead
  of small updates.

## Mitigations

- Keep one controller/state source of truth while changing page composition.
- Add widget coverage for the primary home flow, activity drill-downs, and
  blocked/error diagnostics visibility.
- Keep typed host/tunnel failure summaries visible from the home screen when the
  shell cannot proceed.

## Validation Plan

- `cd mobile/gui_shell && flutter analyze`
- `cd mobile/gui_shell && flutter test`
- `openspec validate refactor-24-mobile-gui-workflow-first-navigation --strict --no-interactive`
