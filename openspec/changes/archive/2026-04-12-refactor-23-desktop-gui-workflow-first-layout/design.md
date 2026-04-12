## Context

The current desktop shell already satisfies the core runtime contract:

- it talks to a compatible local host
- it manages profiles, resolutions, sessions, and diagnostics
- it surfaces typed host and challenge state

The remaining problem is layout and workflow shape.

Today the shell front-loads multiple status banners and then renders a rigid
desktop grid where:

- the left column mixes saved-profile browsing with full profile editing
- the center and right regions reserve large areas for resolutions, sessions,
  and event stream even when those panels are empty
- platform tunnel state and notices compete visually with host readiness before
  the operator reaches the primary actions

This makes the shell feel like an operator console first and a workflow tool
second, even though the common path is still "select a profile, resolve or
start, then inspect activity if needed".

## Goals

- Make the desktop shell task-first without changing the control-plane contract
- Separate profile navigation from active editing
- Reduce top-of-screen status fragmentation
- Keep diagnostics and platform-tunnel detail available without dominating the
  initial view
- Preserve keyboard/mouse desktop affordances and room for richer live panels

## Non-Goals

- Redesign the visual brand, theme family, or typography system from scratch
- Change provider/runtime semantics, validation, or control-plane payloads
- Remove resolutions, sessions, event stream, or platform-tunnel reporting
- Force desktop into a phone-style single-column flow

## Decisions

### Decision: Use one consolidated operational header

Host readiness, compatibility, notices, and platform-tunnel summary should
appear in one top-level shell header.

The header should:

- show the current host state and build/contract summary
- expose reconnect/refresh actions
- summarize platform-tunnel availability and relevant warnings
- expand into more detail only when the operator asks for it or when the shell
  is blocked

This keeps critical state visible without spending three separate stripes of
vertical attention before the workflow begins.

### Decision: Split profile library from active workspace

Saved profiles should move into a dedicated desktop navigation surface such as a
left rail or left list pane.

The active workspace should then own:

- profile draft editing
- provider-specific guidance
- primary actions such as save, resolve, and start
- the currently selected resolution or session context

This preserves quick profile switching while preventing the editor from acting
as both a navigator and a long-form settings dump.

### Decision: Prioritize the active workflow over empty secondary panels

The main canvas should emphasize the active operator step:

1. choose or create a profile
2. resolve or start
3. inspect the selected resolution or session when one exists

Empty resolutions, sessions, and event stream surfaces should collapse, defer,
or render as compact placeholders instead of permanently owning most of the
screen.

### Decision: Keep diagnostics and tunnel detail secondary but reachable

Event stream, detailed platform-tunnel status, and support-oriented metadata
remain part of the desktop shell, but they should live in a secondary panel,
drawer, inspector, or explicitly expanded region.

This change must not weaken fail-closed reporting.
When the host is blocked, incompatible, or reports a typed tunnel failure, the
shell still needs an explicit operator-visible explanation.

## Alternatives Considered

### Keep the current layout and only tune spacing/copy

Rejected.
The main issue is structural: too many responsibilities share the same editor
column and too much screen area is reserved for empty secondary panels.

### Collapse everything into a single form column

Rejected.
That would reduce the dashboard feel, but it would also throw away desktop
navigation affordances and make saved-profile switching worse.

### Move all diagnostics behind a separate route

Rejected.
Desktop operators still benefit from live context on the same screen; the issue
is priority and density, not the mere presence of diagnostics.

## Risks / Trade-offs

- Moving panels around can briefly destabilize widget tests and golden
  expectations.
- A more compact header can accidentally hide important failure state if error
  affordances are not explicit.
- Splitting navigation from editing can create state-sync bugs if selection,
  draft reset, and secondary panel state are not wired carefully.

## Mitigations

- Preserve typed host/tunnel failure text in a clearly visible blocked/error
  path.
- Add widget coverage for the initial empty state, blocked state, profile
  selection, and active resolution/session presence.
- Keep the control-plane model and controller APIs stable while the layout is
  being reorganized.

## Validation Plan

- `cd desktop/gui_shell && flutter analyze`
- `cd desktop/gui_shell && flutter test`
- `openspec validate refactor-23-desktop-gui-workflow-first-layout --strict --no-interactive`
