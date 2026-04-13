## Context

The desktop shell already exposes the right runtime capabilities:

- local host supervision
- profile and managed-provider editing
- typed resolution and session activity
- diagnostics and platform-tunnel inspection

The remaining gap is structural.

The current desktop UI still presents these surfaces as peer cards with similar
visual weight:

- a large operational header
- a stacked library card
- a large central workspace
- a persistent diagnostics column

That composition keeps everything reachable, but it still reads like an
operator dashboard. The primary task competes with support and status surfaces
instead of owning the body.

Material 3 large-window guidance is a better fit for this stage of the shell:

- a leading navigation surface such as a navigation rail or persistent drawer
- one or two primary body panes
- an optional third pane as a secondary inspector side sheet
- no more than three panes at once

## Goals

- Make the desktop shell feel pane-based rather than dashboard-based
- Give navigation, task editing, and diagnostics distinct responsibilities
- Keep the common path visually dominant: choose context, edit, resolve/start
- Preserve explicit fail-closed visibility for blocked host and tunnel failures
- Keep the layout resilient across large and extra-large resizable desktop
  windows

## Non-Goals

- Change provider, profile, resolution, session, or control-plane semantics
- Redesign the desktop visual brand or typography system from scratch
- Remove diagnostics, event stream, or platform-tunnel inspection from desktop
- Force desktop into a phone-style route stack

## Decisions

### Decision: Use a leading desktop navigation surface

The shell should stop using one long "Libraries" card as both navigation and
content.

Instead, desktop should expose a leading navigation surface that can adapt by
window width:

- navigation rail in ordinary large windows
- persistent or expanded drawer in extra-large windows when labels and section
  clarity need more space

This surface owns top-level context switching between primary shell sections
such as the profile workflow, managed-provider workflow, and other future
desktop-level destinations.

Presets stay subordinate to the managed-provider workflow as seed actions.
They must not become a peer top-level navigation taxonomy again, because
`update-23-app-owned-provider-catalog` already fixes them as seed mechanisms
inside the app-owned provider model.

### Decision: Start with a small set of primary desktop sections

The initial pane-shell rollout should not turn every existing surface into a
peer navigation destination.

The first desktop pane model should center on a small set of primary operator
sections:

- the profile workflow
- the managed-provider workflow

Saved profiles remain part of the profile workflow context rather than a third
independent product area.
Diagnostics, tunnel detail, event stream, and live work remain secondary
surfaces unless later evidence shows that they are primary enough to justify
their own section.

This keeps the new rail/drawer from becoming a relabeled dashboard.

### Decision: Use body panes for the active task instead of peer dashboard cards

The central shell body should become the main task region.

Depending on window width and selected destination, that region can use:

- a single dominant task pane
- a fixed + flexible two-pane body
- list/detail or navigation/detail composition

The exact widget composition may vary, but the contract is the same:
the body is where the active task lives, and it should not compete with empty
diagnostics or a long stacked library surface.

### Decision: Keep diagnostics and live work in contextual inspectors

Diagnostics, tunnel detail, event stream, and live activity remain part of the
desktop shell, but they should move into contextual secondary inspectors rather
than a permanently dominant peer column.

The preferred desktop pattern is a side inspector sheet or third pane.
A bottom panel can still be used for timeline-like or log-like surfaces when
horizontal space is tighter, but it should remain secondary and contextual.

For implementation, the inspector should adapt by width:

- coplanar side inspector or third pane in wide desktop layouts
- end-drawer or equivalent overlay inspector in narrower desktop layouts
- bottom panel only for timeline-like or log-like content where vertical
  expansion matches the content shape better than a side pane

When no active work exists, these inspectors may stay collapsed or secondary.
When the host is blocked, incompatible, or the operator is actively inspecting
runtime work, the shell must make the relevant inspector or summary explicitly
reachable without hiding the failure.

### Decision: Replace the hero header with a compact shell bar

Routine host status should not consume the same visual weight as the workspace.

The shell should use a compact top-level shell bar that keeps:

- current readiness/blocked state
- essential actions such as reconnect or refresh
- a short operational summary
- access to expanded tunnel and host detail

Blocked or incompatible states may still pin additional inline explanation, but
the default ready path should not look like a hero banner.

### Decision: Separate shell navigation state from task selection and inspector state

The current controller model overloads `workspaceSurface` for editor mode
selection. That is sufficient for the current card-based screen, but it is too
coarse for a pane-based shell.

The refactor should keep one controller-owned source of truth while splitting
shell state into distinct concerns:

- active top-level desktop section
- current entity selection within that section
- inspector kind and visibility state

Selection ids for profiles, managed providers, resolutions, and sessions remain
independent domain state. They should not implicitly encode top-level shell
navigation.

This prevents layout composition from depending on one overloaded enum and
reduces the risk that a selection change accidentally navigates the entire
shell.

### Decision: Limit shell-wide rebuild churn

The current desktop screen is composed under one controller-driven top-level
`AnimatedBuilder`, which is acceptable for the existing card dashboard but
becomes wasteful in a pane-based shell with inspectors and high-churn activity.

The refactor should keep one controller as the authoritative state owner while
reducing unnecessary full-shell rebuilds through composition boundaries, such
as:

- separate listeners for primary panes and inspector content
- localized rebuilds for notice or activity surfaces
- stable body panes that do not redraw on every event-stream append

This is primarily a responsiveness and maintainability concern, not a change to
runtime semantics.

### Decision: Adapt panes predictably as the desktop window is resized

The desktop shell must not assume that users stay in one large, fixed window.

The shell should define deterministic adaptation rules for at least three
width regimes:

- compacted desktop widths where one dominant body pane is primary and
  secondary surfaces become modal or collapsible
- large widths where a rail plus one or two body panes are available
- extra-large widths where a persistent drawer or third inspector pane may be
  justified

The important contract is not the exact pixel threshold, but that navigation
and inspector panes can enter or leave the layout without discarding the
operator's current draft, selection, or typed runtime context.

### Decision: Use progressive disclosure inside editors

The pane refactor should not just move containers around.

Profile and provider editors should also stop front-loading support-only or
advanced content when the operator first opens the task pane.
Primary form inputs and primary actions should stay immediately visible.
Advanced runtime defaults, verbose capability notes, and support-oriented
details should move behind explicit disclosure.

## Alternatives Considered

### Keep the current layout and only compress spacing/copy

Rejected.
The problem is structural. Smaller cards would still leave navigation,
workspace, and diagnostics acting like equal-weight dashboard regions.

### Move diagnostics to a separate screen only

Rejected.
Desktop operators still need quick access to runtime and support context on the
same screen. The problem is priority and placement, not the existence of
diagnostics.

### Use bottom sheets as the primary desktop inspector model

Rejected.
Material 3 treats bottom sheets as secondary surfaces better suited to compact
and medium layouts. For desktop-sized windows, a side inspector or third pane
is the more appropriate default.

## Risks / Trade-offs

- More explicit section navigation can create state-sync bugs if selected
  destination, selected record, and current draft are not coordinated.
- Inspector auto-open behavior can feel noisy if blocked/error and active-work
  rules are not deterministic.
- Resizable desktop windows can expose breakpoints where the rail/drawer/body
  relationship feels unstable.

## Mitigations

- Keep one controller-owned source of truth while changing shell composition.
- Define deterministic inspector rules for ready, blocked, and active-work
  states before rewriting widgets.
- Define deterministic pane-collapse and state-preservation rules before
  choosing concrete breakpoints.
- Add widget coverage for destination switching, narrow/large desktop layouts,
  and blocked/error surfaces.

## Validation Plan

- `cd desktop/gui_shell && flutter analyze`
- `cd desktop/gui_shell && flutter test`
- `openspec validate refactor-25-desktop-pane-navigation-shell --strict --no-interactive`
