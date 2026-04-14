# Change: [26] Refine the desktop shell around the Focused Workflow direction

## Why
The desktop shell already moved away from the old dashboard layout, but it
still asks the operator to divide attention between too many equally important
surfaces.

The selected reference direction is `Focused Workflow`: one dominant editor for
the current task, a quiet context lane for adjacent workflows and recent items,
and support surfaces that stay secondary until runtime state genuinely demands
attention.

This should be a follow-up refactor on top of the current pane shell, not a
new runtime feature. The local host contract, provider semantics, and session
flows stay unchanged; only the desktop shell hierarchy and workflow emphasis
change.

## Sequence
- Order: `26`
- Depends on: `refactor-25-desktop-pane-navigation-shell`
- Unblocks: later desktop-shell polish and implementation work that needs a
  settled primary workflow hierarchy

## What Changes
- Refine the desktop shell from a generic pane workspace into a focused
  workflow shell with one dominant editor for the active operator task.
- Keep adjacent workflows, recent records, and seed actions in a quieter
  context lane instead of treating them as equal-weight peer content regions.
- Reduce routine ready-state chrome to a compact assurance block instead of a
  shell-wide operational surface that competes with the active editor.
- Keep diagnostics, tunnel detail, event stream, and other support surfaces
  on-demand by default in the ready path while preserving explicit fail-closed
  visibility for blocked or active runtime states.
- Preserve current desktop control-plane semantics, provider/runtime
  capabilities, and fail-closed guarantees; this is a UX-structure refactor.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell/lib/src/ui/...`,
  `desktop/gui_shell/lib/src/control/...`,
  `desktop/gui_shell/test/...`, related desktop shell docs/reference assets
