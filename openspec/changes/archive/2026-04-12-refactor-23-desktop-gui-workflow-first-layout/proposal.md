# Change: [23] Refactor desktop GUI into a workflow-first layout

## Why
The current desktop shell exposes the right control-plane features, but its
information architecture still reads like a diagnostics dashboard with an
embedded editor.

Saved profiles, profile editing, runtime overrides, platform tunnel status,
resolutions, sessions, and event diagnostics all compete on the same screen.
That makes the primary operator workflow harder than it needs to be, especially
when the shell opens with mostly empty secondary panels.

## Sequence
- Order: `23`
- Depends on: `add-02-desktop-gui-shell`,
  `add-21-provider-defined-entry-fields`,
  `refactor-12-flutter-workspace-shell-core`
- Unblocks: later desktop platform-tunnel UX polish under
  `add-18-desktop-platform-tunnel-ready-paths`

## What Changes
- Refactor the desktop shell layout so saved-profile navigation, active profile
  editing, and live runtime work occupy distinct roles instead of one overloaded
  left column plus mostly empty center panels.
- Consolidate host readiness, compatibility, notices, and platform-tunnel
  status into one operational header with progressive disclosure instead of
  multiple competing top-of-screen banners.
- Make the main canvas task-first: create or select a profile, resolve or
  start, then inspect the active resolution/session context without dedicating
  most of the screen to empty diagnostics.
- Keep event stream, detailed platform-tunnel diagnostics, and support-oriented
  metadata available, but secondary to the operator's active workflow.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell/lib/src/ui/...`,
  `desktop/gui_shell/test/...`, desktop shell docs/screenshots
