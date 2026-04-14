## Context

`refactor-25-desktop-pane-navigation-shell` and
`refactor-26-desktop-focused-workflow-shell` both improved the desktop shell,
but they still preserved too much first-screen compatibility with earlier
layouts.

In practice the current desktop screen can still show, or strongly imply, too
many of these at once:

- workflow switching
- preset bootstrap
- reusable provider browsing
- saved profile browsing
- readiness/support chrome
- current editing

That is not a small polish problem. It is an information-architecture problem:
the shell is still trying to reassure the operator that no capability was
visually displaced.

This change treats that behavior as a product problem, not a regression risk to
be preserved. The desktop shell should now break from the earlier "keep
everything nearby" approach and make one primary operator path own the default
screen.

## Goals

- Make the default desktop first read about one active workflow only
- Remove full secondary libraries from the default screen
- Keep secondary capabilities available, but only after explicit operator
  intent
- Preserve compact readiness and fail-closed escalation
- Preserve current control-plane and runtime semantics

## Non-Goals

- Introduce new provider, profile, resolution, or session capabilities
- Change local control-plane contracts or runtime behavior
- Remove presets, saved profiles, or managed-provider libraries from the
  product entirely
- Reintroduce a multi-pane desktop dashboard to preserve prior placement

## Decisions

### Decision: Treat the first screen as a single-path surface

The desktop shell should stop using the first screen as a compromise layout for
multiple workflows.

The default first screen must show:

- one dominant editor for the current task
- a compact readiness/assurance summary
- a minimal task-switch affordance

It must not try to keep full preset, saved-profile, and managed-provider
libraries visible at the same time.

### Decision: Move secondary libraries behind explicit entry surfaces

Saved-profile browsing, managed-provider browsing, preset bootstrap, and
provider-family selection should remain available, but they should open only
after explicit operator intent.

Acceptable surfaces include:

- a dedicated chooser step
- a drawer
- a modal or sheet
- a dedicated task-start route

The important rule is that these surfaces are no longer permanent first-screen
companions.

### Decision: Break desktop placement intentionally

This change is a UX break by design.

The proposal should not optimize for maintaining muscle memory around the old
placement of preset cards, saved profile lists, or reusable provider lists.
Those surfaces may move if the result is a clearer first read.

### Decision: Keep the context lane minimal

If a persistent context lane remains, its job is orientation, not browsing.

It may show:

- current task switch affordances
- one short summary of current context
- one small reminder or shortcut hint

It should not behave like a second scrollable library stack.

### Decision: Keep support secondary and fail-closed

The UX break should not weaken support visibility.

Default ready-state behavior:

- support remains one explicit action away
- support does not permanently occupy the first read

Escalated behavior:

- blocked or incompatible host state pins immediate guidance
- active runtime work may pin compact summary
- full support detail remains reachable without restoring multi-surface first
  screen sprawl

### Decision: Preserve state across explicit secondary surfaces

Removing always-visible libraries must not mean losing work.

When the operator opens and closes a secondary library surface, the shell must
preserve:

- current draft values
- current profile or provider selection
- current support context where relevant
- return path into the active workflow

## Alternatives Considered

### Keep the current shell and only reduce spacing or copy

Rejected.
That would not solve the real problem: too many conceptually distinct surfaces
still compete on the first read.

### Hide only presets and leave the rest of the layout intact

Rejected.
The problem is broader than presets. Saved-profile and managed-provider
libraries can create the same multi-surface first-screen pressure.

### Keep all libraries visible because Git makes rollback cheap

Rejected.
Version control reduces delivery risk, but it does not define a good product
surface. This decision should be driven by operator comprehension, not by fear
of moving UI affordances.

## Risks / Trade-offs

- The UX break may initially feel less discoverable to operators used to
  always-visible libraries.
- Moving preset and library surfaces behind explicit entry points adds an extra
  click for some flows.
- If the new task-start affordances are vague, the shell can become simpler but
  harder to learn.

## Mitigations

- Make task-start actions explicit and named by intent, not by internal data
  structure.
- Preserve keyboard shortcuts and obvious return paths.
- Keep one short contextual summary visible so the shell does not feel empty or
  disorienting.
- Add widget coverage for entry, exit, and context preservation around the new
  secondary surfaces.

## Migration Plan

1. Update the desktop shell contract to stop promising first-screen co-visibility.
2. Introduce the new explicit secondary entry surfaces.
3. Reduce the persistent context lane to orientation only.
4. Update widget tests, docs, and screenshots to match the break.

## Open Questions

- The exact form of the task-start surface can stay open between drawer, modal,
  or dedicated step as long as it is explicit and no longer permanent on the
  first screen.
