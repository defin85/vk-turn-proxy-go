# Change: [27] Break the desktop shell into a single-path workflow UX

## Why
`refactor-26-desktop-focused-workflow-shell` improved hierarchy, but it still
preserved too much first-screen co-visibility from the earlier pane shell.

The current desktop surface can still ask the operator to parse workflow
switching, presets, reusable-record libraries, readiness, and editor content at
the same time. That keeps too much legacy information architecture on screen in
the name of continuity.

The next step should be an explicit UX break: the desktop shell should stop
trying to keep every major workflow surface visible at once and instead commit
to one primary operator path per first read.

## Sequence
- Order: `27`
- Depends on: `refactor-26-desktop-focused-workflow-shell`
- Unblocks: later desktop-shell polish that depends on a stable single-path
  desktop interaction model instead of preserving multi-surface first-screen
  compatibility

## What Changes
- **BREAKING** Reduce the default desktop first screen to one dominant workflow
  path plus minimal task-switch context instead of co-rendering full saved
  profile, managed-provider, and preset libraries beside the active editor.
- Move preset bootstrap, saved-profile browsing, managed-provider browsing, and
  provider-family selection into explicit task-start surfaces such as a picker,
  drawer, modal, or dedicated workflow step instead of always-on companion
  columns.
- Constrain the persistent desktop context lane to orientation and current-task
  switching only; it should no longer behave like a second scrollable content
  wall.
- Keep readiness compact and support on-demand by default, with explicit
  fail-closed escalation for blocked hosts or active runtime work.
- Preserve control-plane, provider, profile, resolution, and session semantics;
  this is a desktop information-architecture break, not a runtime or contract
  break.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell/lib/src/ui/...`,
  `desktop/gui_shell/test/...`, desktop shell docs/reference assets
